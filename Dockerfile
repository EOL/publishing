FROM eol_seabolt_rails:2021.10.04.01
LABEL maintainer="Jeremy Rice <jrice@eol.org>"
LABEL last_full_rebuild="2021-10-04"

COPY . /app
COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY config/nginx.conf /etc/nginx/nginx.conf

# Set up mail (for user notifications, which are rare but critical)
# root is the person who gets all mail for userids < 1000
RUN echo "root=admin@eol.org" >> /etc/ssmtp/ssmtp.conf
# Here is the gmail configuration (or change it to your private smtp server)
RUN echo "mailhub=smtp-relay.gmail.com:25" >> /etc/ssmtp/ssmtp.conf

RUN echo "UseTLS=YES" >> /etc/ssmtp/ssmtp.conf
RUN echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf

RUN gem install bundler:2.1.4
RUN bundle config set without 'test development staging'
RUN bundle install --jobs 10 --retry 5
# Skipping this for now. The secrets file does not work during a `docker-compose build`. :\
# RUN cd app && rake assets:precompile

RUN touch /tmp/supervisor.sock
RUN chmod 777 /tmp/supervisor.sock
RUN ln -s /tmp /app/tmp

WORKDIR /app

EXPOSE 3000

ENTRYPOINT ["/app/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
