FROM ruby:2.4.4
MAINTAINER Jeremy Rice <jrice@eol.org>

ENV LAST_FULL_REBUILD 2018-08-14

RUN apt-get update -q && \
    apt-get install -qq -y build-essential libpq-dev curl wget openssh-server openssh-client \
    apache2-utils nodejs procps supervisor vim nginx logrotate && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

ENV LAST_SOURCE_UPDATE 2018-08-17-01

COPY . /app
COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
# NOTE: supervisord *service* doesn't work with custom config files, so just use default:
COPY config/supervisord.conf /etc/supervisor/supervisord.conf
COPY Gemfile ./

RUN bundle install --jobs 10 --retry 5 --without test development staging

RUN touch /tmp/supervisor.sock
RUN chmod 777 /tmp/supervisor.sock

EXPOSE 3000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
