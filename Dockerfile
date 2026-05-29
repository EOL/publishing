# syntax=docker/dockerfile:1.7

FROM encoflife/eol_seabolt_rails:2024.05.09.01 AS assets
# WARNING:                       ^^^^^^^^^^^^^ when you update that, ALSO update it below!
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

# This removes a problem with asset compiling (SSL within node):
ENV NODE_OPTIONS="--openssl-legacy-provider"\
    NODE_ENV="production"\
    BUNDLE_PATH="/gems"

COPY Gemfile Gemfile.lock package.json yarn.lock ./
RUN gem install "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1 | sed 's/^[[:space:]]*/bundler:/')" \
  && bundle config set --global path /gems \
  && bundle config set without 'test development staging' \
  && bundle install --jobs 10 --retry 1 \
  && yarn install --frozen-lockfile

# Copy the rest of the app only after dependency layers are cached.
COPY . /app
RUN mkdir -p /app/tmp && chmod +x bin/rails bin/rake

ARG rails_env
ARG neo4j_driver_url
ARG neo4j_user

# You will want to build using a command like this:
# export $(grep -v '^#' .env | xargs) && dc build --secret id=rails_master_key,env=RAILS_MASTER_KEY \
# --build-arg rails_env=$RAILS_ENV --build-arg traitbank_url=$TRAITBANK_URL \
# --build-arg neo4j_driver_url=$NEO4J_DRIVER_URL --build-arg neo4j_user=$NEO4J_USER \
# --secret id=neo4j_password,env=NEO4J_PASSWORD
ENV LD_LIBRARY_PATH="/usr/local/lib"
RUN --mount=type=secret,id=rails_master_key,required=true \
  --mount=type=secret,id=neo4j_password,required=true \
  RAILS_MASTER_KEY="$(cat /run/secrets/rails_master_key)" RAILS_ENV=${rails_env} \
  TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url} \
  NEO4J_USER=${neo4j_user} NEO4J_PASSWORD="$(cat /run/secrets/neo4j_password)" \
  bundle exec rails assets:precompile

# -=-=-=-=-=-=-

FROM encoflife/eol_seabolt_rails:2024.05.09.01 AS app
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

ENV NODE_OPTIONS="--openssl-legacy-provider"\
  NODE_ENV="production"\
  BUNDLE_PATH="/gems"

COPY --from=assets /usr/local/bundle /usr/local/bundle
COPY --from=assets /gems /gems
COPY . /app
COPY --from=assets /app/public/assets /app/public/assets
COPY --from=assets /app/public/packs /app/public/packs
# Just to save me a few grey hairs:
COPY config/.vimrc /root/.vimrc

ARG eol_github_email
ARG eol_github_user

RUN git config --global user.email "${eol_github_email}" && \
  git config --global user.name "${eol_github_user}" && \
  git config --global pull.rebase false

RUN chmod 0755 bin/* && \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/seabolt.conf && \
  ldconfig
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENTRYPOINT ["/app/bin/entrypoint.sh"]
EXPOSE 3000
