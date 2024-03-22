FROM encoflife/eol_seabolt_rails:2024.03.22.01
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
LABEL last_full_rebuild="2024-03-21"

WORKDIR /app

# This seems redundant, but if we don't do this, we can't build this container with NEW code:
COPY . /app

RUN ln -s /tmp /app/tmp
ENV NODE_OPTIONS '--openssl-legacy-provider npm run start'
ENV NODE_ENV production

ENV BUNDLE_PATH /gems

RUN gem install `tail -n 1 Gemfile.lock | sed 's/^\s\+/bundler:/'`
RUN bundle config set without 'test development staging'
RUN bundle install --jobs 10 --retry 1

RUN yarn install
RUN bin/webpack
RUN bundle exec rails assets:precompile

# Copying the directory again in case we locally updated the code (but don't have to rebuild seabolt!)
COPY . /app
# Just to save me a few grey hairs:
COPY config/.vimrc /root/.vimrc

SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.email '$EOL_GITHUB_EMAIL'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.name '$EOL_GITHUB_USER'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global pull.rebase false"]

ENTRYPOINT ["/app/bin/entrypoint.sh"]
EXPOSE 9393