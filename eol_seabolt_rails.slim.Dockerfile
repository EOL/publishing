# syntax=docker/dockerfile:1.7
#
# eol_seabolt_rails -- slim rebuild, two published targets:
#
#   build   : everything needed to `bundle install`, `yarn install`, and
#             `assets:precompile` (compilers, headers, git, Node+yarn).
#             Used ONLY by the app Dockerfile's assets stage; never deployed.
#   runtime : shared libraries only. No compilers, no Node, no sshd, no
#             editors. This is what runs in the cluster.
#
# Build & push (from a machine with podman):
#   podman build --target build   -t ghcr.io/tzurita/eol_seabolt_rails:<DATE>-build   .
#   podman build --target runtime -t ghcr.io/tzurita/eol_seabolt_rails:<DATE>-runtime .
#   podman push ghcr.io/tzurita/eol_seabolt_rails:<DATE>-build
#   podman push ghcr.io/tzurita/eol_seabolt_rails:<DATE>-runtime
# then resolve both digests (skopeo inspect --format '{{.Digest}}') and pin
# them in the app Dockerfile's FROM lines.
#
# Debian 11 (bullseye) is required: seabolt fails to build on Debian 12.
# Ruby pinned at 3.3.1 to match .ruby-version; bump deliberately.

############################################################
# Stage 1: seabolt builder (unchanged behavior from legacy)
############################################################
FROM ruby:3.3.1-slim-bullseye@sha256:07a28c3974d2e40200e49d577a84cf35045ec1162a404bc4e794ed006022c05a AS seabolt-builder
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

ARG SEABOLT_PACKAGE_VERSION=1.7.4

RUN apt-get update -q && \
    apt-get install -qq -y --no-install-recommends \
      build-essential ca-certificates cmake git \
      libssl-dev pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# NOTE: make_debug.sh is what the legacy base used; preserved verbatim so the
# produced library name/ABI matches what the neo4j ruby driver expects.
# (Switching to a release build is a separate, testable change.)
RUN git clone --depth 1 https://github.com/neo4j-drivers/seabolt.git /seabolt && \
    cd /seabolt && \
    ./make_debug.sh && \
    cd build && \
    cpack && \
    mkdir /seabolt-package && \
    tar xzf "/seabolt/build/dist-package/seabolt-${SEABOLT_PACKAGE_VERSION}-dev-Linux-debian-11.tar.gz" -C /seabolt-package --strip-components=1

############################################################
# Stage 2: BUILD target -- app asset/gem compilation only
############################################################
FROM ruby:3.3.1-slim-bullseye@sha256:07a28c3974d2e40200e49d577a84cf35045ec1162a404bc4e794ed006022c05a AS build
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
WORKDIR /app

# Toolchain for native gem extensions + git for git-sourced gems
# (eol_terms) + headers for pg. Node 18 + yarn for webpacker asset builds
# (Node here is build-tooling only; it never ships in runtime).
RUN apt-get update -q && \
    apt-get install -qq -y --no-install-recommends \
      build-essential git ca-certificates curl \
      libpq-dev default-libmysqlclient-dev pkg-config && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update -q && \
    apt-get install -qq -y --no-install-recommends nodejs && \
    npm install -g --no-fund yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Seabolt: assets:precompile boots the app, which FFI-loads the library.
COPY --from=seabolt-builder /seabolt-package/ /
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/seabolt.conf && ldconfig

############################################################
# Stage 3: RUNTIME target -- what actually runs in the cluster
############################################################
FROM ruby:3.3.1-slim-bullseye@sha256:07a28c3974d2e40200e49d577a84cf35045ec1162a404bc4e794ed006022c05a AS runtime
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
WORKDIR /app

# Runtime shared libraries only:
#   libpq5     -- pg gem (runtime lib; -dev headers stay in build)
#   libmariadb3 -- mysql2 gem runtime lib (headers: default-libmysqlclient-dev
#                  in build). If `grep pg Gemfile` is empty, libpq5/libpq-dev
#                  can be dropped from both targets on a future pass.
#   procps  -- ps/top for in-cluster debugging (tiny, low risk)
#   curl    -- httpGet-style debugging and any app-level shellouts; remove
#              if audit shows nothing uses it
# Deliberately ABSENT vs legacy base: build-essential, git, wget,
# openssh-server/client, apache2-utils, vim, logrotate, msmtp/ssmtp,
# gnupg, nodejs, yarn.
RUN apt-get update -q && \
    apt-get install -qq -y --no-install-recommends \
      ca-certificates libpq5 libmariadb3 procps curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=seabolt-builder /seabolt-package/ /
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/seabolt.conf && ldconfig
