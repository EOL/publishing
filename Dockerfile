FROM encoflife/eol-rails:2024-10-29.01 AS assets
# WARNING:               ^^^^^^^^^^^^^ when you update that, ALSO update it below!
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

# This seems redundant, but if we don't do this, we can't build this container with NEW code:
COPY . /app

RUN ln -s /tmp /app/tmp
# This removes a problem with asset compiling (SSL within node):
ENV NODE_OPTIONS="--openssl-legacy-provider npm run start"\
    NODE_ENV="production"\
    BUNDLE_PATH="/gems"

RUN gem install `grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1 | sed 's/^\s\+/bundler:/'`\
  && bundle config set without 'test development staging'\
  && bundle install --jobs 10 --retry 1\
  && bundle config set --global path /gems\
  && yarn install

ARG rails_secret_key
ARG rails_env
ARG traitbank_url
ARG neo4j_driver_url
ARG neo4j_user
ARG neo4j_password

# You will want to build using a command like this:
# export $(grep -v '^#' .env | xargs) && dc build --build-arg rails_secret_key=$RAILS_MASTER_KEY \
# --build-arg rails_env=$RAILS_ENV --build-arg traitbank_url=$TRAITBANK_URL \
# --build-arg neo4j_driver_url=$NEO4J_DRIVER_URL --build-arg neo4j_user=$NEO4J_USER \
# --build-arg neo4j_password=$NEO4J_PASSWORD 
RUN RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env}\
  TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url}\
  NEO4J_USER=${neo4j_user} NEO4J_PASSWORD=${neo4j_password}\ 
  && RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env}\
  TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url}\
  NEO4J_USER=${neo4j_user} NEO4J_PASSWORD=${neo4j_password}\
  bundle exec rails assets:precompile

# -=-=-=-=-=-=-

FROM encoflife/eol-rails:2024-10-29.01 AS app
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

COPY --chown=ruby:ruby bin/ ./bin
RUN chmod 0755 bin/*

ENV NODE_OPTIONS="--openssl-legacy-provider npm run start"\
  NODE_ENV="production"\
  BUNDLE_PATH="/gems"

# Copying the directory again in case we locally updated the code (but don't have to rebuild seabolt!)
COPY . /app
COPY --from=assets /usr/local/bundle /usr/local/bundle
COPY --from=assets /gems /gems
COPY --from=assets /app/public/assets /app/public/assets
COPY --from=assets /app/public/packs /app/public/packs
COPY --from=assets /app/Gemfile /app/Gemfile.lock /app/.
# Just to save me a few grey hairs:
COPY config/.vimrc /root/.vimrc

RUN bundle install --jobs 10 --retry 1\
  && bundle config set --global path /gems

ARG eol_github_email
ARG eol_github_user

RUN git config --global user.email ${eol_github_email}
RUN git config --global user.name ${eol_github_user}
RUN git config --global pull.rebase false

ENTRYPOINT ["/app/bin/entrypoint.sh"]
EXPOSE 3000