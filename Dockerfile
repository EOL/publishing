FROM encoflife/eol_seabolt_rails:latest
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
LABEL last_full_rebuild="2021-10-28"

WORKDIR /app

RUN touch /tmp/supervisor.sock
RUN chmod 777 /tmp/supervisor.sock
RUN ln -s /tmp /app/tmp

# Copying the directory again in case we locally updated the code (but don't have to rebuild seabolt!)
COPY . /app

SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.email '$EOL_GITHUB_EMAIL'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.name '$EOL_GITHUB_USER'"]

RUN RAILS_ENV=production bundle install
RUN RAILS_ENV=production bundle update eol_terms
RUN RAILS_ENV=production bundle exec rake assets:precompile

# SHELL ["/bin/bash", "-c" , "source /app/docker/.env && /usr/local/bundle/bin/bundle install"]
# SHELL ["/bin/bash", "-c" , "source /app/docker/.env && /usr/local/bundle/bin/bundle update eol_terms"]

EXPOSE 3000

ENTRYPOINT ["/app/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
