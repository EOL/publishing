FROM ruby:2.4.2
MAINTAINER Jeremy Rice <jrice@eol.org>

ENV LAST_FULL_REBUILD 2018-08-14

RUN apt-get update -q && \
    apt-get install -qq -y curl wget openssh-server openssh-client \
    software-properties-common nodejs procps \
    libmysqlclient-dev libqt4-dev supervisor vim && \
    add-apt-repository -y ppa:nginx/stable && \
    apt-get update && \
    apt-get install -qq -y nginx && \
    apt-get -qq -y --force-yes install cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY . /app
COPY Gemfile Gemfile.lock ./
COPY config/crontab /etc/cron.d/rake-cron

RUN chmod 0644 /etc/cron.d/rake-cron
RUN crontab /etc/cron.d/rake-cron

RUN bundle install --without test development staging

EXPOSE 3000
CMD ["/usr/bin/supervisord", "-c", "/app/config/supervisord.conf"]
