FROM encoflife/eol_seabolt_rails:2024.03.21.01
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
LABEL last_full_rebuild="2024-03-21"

WORKDIR /app

RUN touch /tmp/supervisor.sock
RUN chmod 777 /tmp/supervisor.sock
RUN ln -s /tmp /app/tmp

# Copying the directory again in case we locally updated the code (but don't have to rebuild seabolt!)
COPY . /app

SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.email '$EOL_GITHUB_EMAIL'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global user.name '$EOL_GITHUB_USER'"]
SHELL ["/bin/bash", "-c" , "source /app/docker/.env && git config --global pull.rebase false"]

EXPOSE 9393

ENTRYPOINT ["/app/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
