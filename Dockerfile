# syntax=docker/dockerfile:1.7
#
# Bases are the slim eol_seabolt_rails targets (see
# eol_seabolt_rails.slim.Dockerfile): the assets stage uses the 'build'
# target (toolchain+Node), the app stage uses the 'runtime' target (shared
# libs only). Pinned by digest; to update, push new base tags, resolve with
#   skopeo inspect --format '{{.Digest}}' docker://ghcr.io/eol/eol_seabolt_rails:<tag>
# and replace tag+digest below.

FROM ghcr.io/eol/eol_seabolt_rails@sha256:0d13e5b4c6b09665d3b7aee742c356b7823b739ca7fdf96fe0b540b50eead42d AS assets
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

# NODE_OPTIONS legacy-provider is needed ONLY here, for webpack asset
# compilation under Node 18+ OpenSSL 3. It must NOT be set in the runtime
# stage (it downgrades OpenSSL behavior for any node process).
ENV NODE_OPTIONS="--openssl-legacy-provider" \
    NODE_ENV="production" \
    BUNDLE_PATH="/gems"

COPY Gemfile Gemfile.lock package.json yarn.lock ./
# NOTE: 'staging' deliberately NOT excluded -- the app runs with
# RAILS_ENV=staging in eol-dev; excluding the group is a latent LoadError
# if a :staging gem is ever added. (Group is empty today, so this changes
# nothing in the built image.)
RUN gem install "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1 | sed 's/^[[:space:]]*/bundler:/')" \
  && bundle config set --global path /gems \
  && bundle config set without 'test development' \
  && bundle install --jobs 10 --retry 1 \
  && yarn install --frozen-lockfile

# Copy the rest of the app only after dependency layers are cached.
COPY . /app
RUN mkdir -p /app/tmp && chmod +x bin/rails bin/rake

ARG rails_env=staging
# Boot-satisfaction placeholders: assets:precompile boots the full app, and
# the Neo4j/traitbank initializers construct the driver at boot -- the driver
# RESOLVES the hostname at construction (an .invalid hostname breaks boot
# with Neo4jException 700/1792) but connects lazily, so a resolvable address
# nothing listens on is sufficient. Compiled assets don't use these values;
# runtime config (configmap + mounted secrets) overrides everything.
# Do NOT pass real values: build args are recorded in image metadata.
ARG traitbank_url=http://127.0.0.1:7474
ARG neo4j_driver_url=bolt://127.0.0.1:7687
ARG neo4j_user=placeholder

# Build with:
#   docker build --secret id=rails_master_key,env=RAILS_MASTER_KEY \
#                --secret id=neo4j_password,env=NEO4J_PASSWORD .
# No --build-arg flags needed; the ARG defaults above are sufficient.
ENV LD_LIBRARY_PATH="/usr/local/lib"
RUN --mount=type=secret,id=rails_master_key,required=true \
  --mount=type=secret,id=neo4j_password,required=true \
  ASSETS_PRECOMPILE=true RAILS_MASTER_KEY="$(cat /run/secrets/rails_master_key)" RAILS_ENV=${rails_env} \
  TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url} \
  NEO4J_USER=${neo4j_user} NEO4J_PASSWORD="$(cat /run/secrets/neo4j_password)" \
  bundle exec rails assets:precompile

# -=-=-=-=-=-=-

FROM ghcr.io/eol/eol_seabolt_rails@sha256:0d13e5b4c6b09665d3b7aee742c356b7823b739ca7fdf96fe0b540b50eead42d AS app
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

# No NODE_OPTIONS here -- runtime never compiles assets.
# BUNDLE_FROZEN forbids any runtime modification of the gem set: if a
# stray `bundle install/update` ever creeps back into the entrypoint or
# an exec'd shell, it fails loudly instead of mutating the container.
ENV BUNDLE_PATH="/gems" \
    BUNDLE_FROZEN="true" \
    LD_LIBRARY_PATH="/usr/local/lib"

COPY --from=assets /usr/local/bundle /usr/local/bundle
COPY --from=assets /gems /gems
COPY . /app
COPY --from=assets /app/public/assets /app/public/assets
COPY --from=assets /app/public/packs /app/public/packs
# The lockfile as actually resolved at build time, so the runtime image
# records exactly what was installed.
COPY --from=assets /app/Gemfile.lock /app/Gemfile.lock

RUN chmod 0755 bin/* && \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/seabolt.conf && \
  ldconfig

# Non-root runtime user. Numeric USER so the kubelet can verify
# runAsNonRoot without inspecting /etc/passwd. a+rX normalizes read/exec
# for everyone regardless of the build checkout's umask; only tmp and log
# are writable by the app user (k8s mounts emptyDir/PVCs over them anyway).
RUN groupadd --system --gid 1000 rails \
 && useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash \
 && chmod -R a+rX /app /gems /usr/local/bundle \
 && mkdir -p /app/tmp /app/log \
 && chown -R rails:rails /app/tmp /app/log
USER 1000:1000

ENTRYPOINT ["/app/bin/entrypoint.sh"]
EXPOSE 3000

