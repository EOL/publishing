FROM ubuntu:xenial
MAINTAINER Jeremy Rice <jrice@eol.org>

ENV LAST_FULL_REBUILD 2016-11-10
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV LANG en_US.UTF-8

RUN apt-get update -q && \
    apt-get install -qq -y curl wget openssh-server openssh-client \
    software-properties-common nodejs \
    libmysqlclient-dev libqt4-dev supervisor vim && \
    add-apt-repository -y ppa:nginx/stable && \
    apt-get update && \
    apt-get install -qq -y nginx && \
    echo "\ndaemon off;" >> /etc/nginx/nginx.conf && \
    chown -R www-data:www-data /var/lib/nginx && \
    apt-get -qq -y --force-yes install cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \curl -ksSL https://get.rvm.io | bash -s stable --ruby
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

ENV PATH /usr/local/rvm/bin:/usr/local/rvm/rubies/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /app

COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY . /app
COPY config/crontab /etc/cron.d/rake-cron

RUN chmod 0644 /etc/cron.d/rake-cron
RUN crontab /etc/cron.d/rake-cron

RUN bundle install --without test development staging

CMD /usr/bin/supervisord
