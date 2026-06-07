# syntax=docker/dockerfile:1.7
#
# Get the digest below with:
#   docker buildx imagetools inspect encoflife/eol_seabolt_rails:2024.05.09.01
# then replace <DIGEST> in BOTH FROM lines. Tag stays for humans; the
# digest is what the build actually uses (tags are mutable, digests are not).

FROM encoflife/eol_seabolt_rails:2024.05.09.01@sha256:537d146ea1ec138a2fe5b0ee842c24b14d126521571aca215ccc81edfb978709 AS assets
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

ARG rails_env
ARG traitbank_url
ARG neo4j_driver_url
ARG neo4j_user

# Build with something like:
# export $(grep -v '^#' .env | xargs) && docker build \
#   --secret id=rails_master_key,env=RAILS_MASTER_KEY \
#   --secret id=neo4j_password,env=NEO4J_PASSWORD \
#   --build-arg rails_env=$RAILS_ENV --build-arg traitbank_url=$TRAITBANK_URL \
#   --build-arg neo4j_driver_url=$NEO4J_DRIVER_URL --build-arg neo4j_user=$NEO4J_USER .
ENV LD_LIBRARY_PATH="/usr/local/lib"
RUN --mount=type=secret,id=rails_master_key,required=true \
  --mount=type=secret,id=neo4j_password,required=true \
  RAILS_MASTER_KEY="$(cat /run/secrets/rails_master_key)" RAILS_ENV=${rails_env} \
  TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url} \
  NEO4J_USER=${neo4j_user} NEO4J_PASSWORD="$(cat /run/secrets/neo4j_password)" \
  bundle exec rails assets:precompile

# -=-=-=-=-=-=-

FROM encoflife/eol_seabolt_rails:2024.05.09.01@sha256:537d146ea1ec138a2fe5b0ee842c24b14d126521571aca215ccc81edfb978709 AS app
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

# No NODE_OPTIONS here -- runtime never compiles assets.
# BUNDLE_FROZEN forbids any runtime modification of the gem set: if a
# stray `bundle install/update` ever creeps back into the entrypoint or
# an exec'd shell, it fails loudly instead of mutating the container.
ENV NODE_ENV="production" \
    BUNDLE_PATH="/gems" \
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
