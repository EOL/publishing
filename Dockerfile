FROM encoflife/eol_seabolt_rails:2024.03.22.01 AS assets
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
LABEL last_full_rebuild="2024-03-21"

WORKDIR /app

# This seems redundant, but if we don't do this, we can't build this container with NEW code:
COPY . /app

RUN ln -s /tmp /app/tmp
# This removes a problem with asset compiling (SSL within node):
ENV NODE_OPTIONS="--openssl-legacy-provider npm run start" \
    NODE_ENV="production" \
    BUNDLE_PATH="/gems"

RUN gem install `tail -n 1 Gemfile.lock | sed 's/^\s\+/bundler:/'` \
  && bundle config set without 'test development staging' \
  && bundle install --jobs 10 --retry 1 \
  && yarn install

ARG rails_secret_key
ARG rails_env
# You will want to build using a command like this:
# export $(grep -v '^#' .env | xargs) && dc build \
#   --build-arg rails_secret_key=$RAILS_MASTER_KEY \
#   --build-arg rails_env=$RAILS_ENV
RUN RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env} bin/webpack \ 
  && RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env} bundle exec rails assets:precompile

CMD ["bash"]

# -=-=-=-=-=-=-

FROM encoflife/eol_seabolt_rails:2024.03.22.01 AS app
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

COPY --chown=ruby:ruby bin/ ./bin
RUN chmod 0755 bin/*

ARG rails_secret_key
ARG rails_env

# Copying the directory again in case we locally updated the code (but don't have to rebuild seabolt!)
COPY . /app
COPY --from=assets /usr/local/bundle /usr/local/bundle
COPY --from=assets /gems /gems
COPY --from=assets /app/public/assets /app/public/assets
COPY --from=assets /app/public/packs /app/public/packs
# Just to save me a few grey hairs:
COPY config/.vimrc /root/.vimrc

SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.email '$EOL_GITHUB_EMAIL'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.name '$EOL_GITHUB_USER'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global pull.rebase false"]

ENTRYPOINT ["/app/bin/entrypoint.sh"]
EXPOSE 3000