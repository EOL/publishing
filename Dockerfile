FROM ruby:2.4.4
MAINTAINER Jeremy Rice <jrice@eol.org>

ENV LAST_FULL_REBUILD 2018-08-14

RUN apt-get update -q && \
    apt-get install -qq -y build-essential libpq-dev curl wget openssh-server openssh-client cron \
    apache2-utils nodejs procps supervisor vim nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY . /app
COPY Gemfile ./
COPY config/crontab /etc/cron.d/rake-cron

RUN chmod 0644 /etc/cron.d/rake-cron
RUN crontab /etc/cron.d/rake-cron

RUN bundle install --jobs 10 --retry 5 --without test development staging

EXPOSE 3000
CMD ["/usr/bin/supervisord", "-c", "/app/config/supervisord.conf"]
