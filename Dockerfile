FROM encoflife/eol_seabolt_rails:2024.03.22.01 AS assets
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
LABEL last_full_rebuild="2024-03-21"

WORKDIR /app

RUN RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env}\
  TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url}\
  NEO4J_USER=${neo4j_user} NEO4J_PASSWORD=${neo4j_password}\ 
  && echo "$RAILS_ENV $TRAITBANK_URL $NEO4J_DRIVER_URL $NEO4J_USER $NEO4J_PASSWORD" > foo.txt

SHELL ["/bin/bash", "-c" , "source /app/docker/.env && echo $RAILS_ENV $TRAITBANK_URL $NEO4J_DRIVER_URL $NEO4J_USER $NEO4J_PASSWORD"]
ENTRYPOINT ["/bin/bash"]
# RUN sleep 300

# # This seems redundant, but if we don't do this, we can't build this container with NEW code:
# COPY . /app

# RUN ln -s /tmp /app/tmp
# # This removes a problem with asset compiling (SSL within node):
# ENV NODE_OPTIONS="--openssl-legacy-provider npm run start"\
#     NODE_ENV="production"\
#     BUNDLE_PATH="/gems"

# RUN gem install `tail -n 1 Gemfile.lock | sed 's/^\s\+/bundler:/'`\
#   && bundle config set without 'test development staging'\
#   && bundle install --jobs 10 --retry 1\
#   && bundle config set --global path /gems\
#   && yarn install

# ARG rails_secret_key
# ARG rails_env
# # You will want to build using a command like this:
# # export $(grep -v '^#' .env | xargs) && dc build --build-arg rails_secret_key=$RAILS_MASTER_KEY \
# # --build-arg rails_env=$RAILS_ENV --build-arg traitbank_url=$TRAITBANK_URL \
# # --build-arg neo4j_driver_url=$NEO4J_DRIVER_URL --build-arg neo4j_user=$NEO4J_USER \
# # --build-arg neo4j_password=$NEO4J_PASSWORD 
# RUN RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env}\
#   TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url}\
#   NEO4J_USER=${neo4j_user} NEO4J_PASSWORD=${neo4j_password}\ 
#   && RAILS_MASTER_KEY=${rails_secret_key} RAILS_ENV=${rails_env}\
#   TRAITBANK_URL=${traitbank_url} NEO4J_DRIVER_URL=${neo4j_driver_url}\
#   NEO4J_USER=${neo4j_user} NEO4J_PASSWORD=${neo4j_password}\
#   bundle exec rails assets:precompile

# CMD ["bash"]

# # -=-=-=-=-=-=-

# FROM encoflife/eol_seabolt_rails:2024.03.22.01 AS app
# LABEL maintainer="Jeremy Rice <jrice@eol.org>"

# WORKDIR /app

# COPY --chown=ruby:ruby bin/ ./bin
# RUN chmod 0755 bin/*

# ARG rails_secret_key
# ARG rails_env

# ENV NODE_OPTIONS="--openssl-legacy-provider npm run start"\
#   NODE_ENV="production"\
#   BUNDLE_PATH="/gems"

# # Copying the directory again in case we locally updated the code (but don't have to rebuild seabolt!)
# COPY . /app
# COPY --from=assets /usr/local/bundle /usr/local/bundle
# COPY --from=assets /gems /gems
# COPY --from=assets /app/public/assets /app/public/assets
# COPY --from=assets /app/public/packs /app/public/packs
# COPY --from=assets /app/Gemfile /app/Gemfile.lock /app/.
# # Just to save me a few grey hairs:
# COPY config/.vimrc /root/.vimrc

# RUN bundle config set without 'test development staging'\
#   && bundle install --jobs 10 --retry 1\
#   && bundle config set --global path /gems

# SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.email '$EOL_GITHUB_EMAIL'"]
# SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.name '$EOL_GITHUB_USER'"]
# SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global pull.rebase false"]

# ENTRYPOINT ["/app/bin/entrypoint.sh"]
# EXPOSE 3000