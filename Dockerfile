FROM ruby:2.4.4
MAINTAINER Jeremy Rice <jrice@eol.org>

ENV LAST_FULL_REBUILD 2018-08-14

RUN apt-get update -q && \
    apt-get install -qq -y build-essential libpq-dev curl wget openssh-server openssh-client \
    apache2-utils nodejs procps supervisor vim nginx logrotate ssmtp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

ENV LAST_SOURCE_UPDATE 2018-08-17-02

COPY . /app
COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY config/nginx.conf /etc/nginx/nginx.conf
# NOTE: supervisord *service* doesn't work with custom config files, so just use default:
COPY config/supervisord.conf /etc/supervisord.conf
COPY Gemfile ./

# Set up mail (for user notifications, which are rare but critical)

# root is the person who gets all mail for userids < 1000
RUN echo "root=admin@eol.org" >> /etc/ssmtp/ssmtp.conf
# Here is the gmail configuration (or change it to your private smtp server)
RUN echo "mailhub=smtp-relay.gmail.com:25" >> /etc/ssmtp/ssmtp.conf

RUN echo "UseTLS=YES" >> /etc/ssmtp/ssmtp.conf
RUN echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf

COPY docker/resources/secrets.yml /app/config/secrets.yml

RUN bundle install --jobs 10 --retry 5 --without test development staging
RUN /bin/bash -l -c "cd /app && bundle exec rake assets:precompile RAILS_ENV=staging"

RUN touch /tmp/supervisor.sock
RUN chmod 777 /tmp/supervisor.sock
RUN ln -s /tmp /app/tmp

EXPOSE 3000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
