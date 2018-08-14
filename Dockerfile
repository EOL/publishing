FROM ubuntu:xenial
MAINTAINER Jeremy Rice <jrice@eol.org>

ENV LAST_FULL_REBUILD 2016-11-10
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV LANG en_US.UTF-8

RUN apt-get update -q && \
    apt-get install -qq -y curl wget openssh-server openssh-client \
    software-properties-common nodejs gnupg2 \
    libmysqlclient-dev libqt4-dev supervisor vim && \
    add-apt-repository -y ppa:nginx/stable && \
    apt-get update && \
    apt-get install -qq -y nginx && \
    echo "\ndaemon off;" >> /etc/nginx/nginx.conf && \
    chown -R www-data:www-data /var/lib/nginx && \
    apt-get -qq -y --force-yes install cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN \command curl -sSL https://rvm.io/mpapis.asc | gpg --import -
RUN \curl -ksSL https://get.rvm.io | bash -s stable --ruby
RUN echo 'source /etc/profile.d/rvm.sh' >> ~/.bashrc
RUN /usr/local/rvm/bin/rvm-shell -c "rvm requirements"
RUN /bin/bash -l -c "rvm autolibs enable"
RUN /bin/bash -l -c "rvm install 2.4.2"
RUN echo "gem: --no-rdoc --no-ri" >> ~/.gemrc
RUN /bin/bash -l -c "gem install bundler"
# This seems to put a copy in /usr/local/rvm/rubies/default/bin which is in our path...
RUN /usr/local/rvm/rubies/default/bin/gem install bundler

ENV PATH /usr/local/rvm/bin:/usr/local/rvm/rubies/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /app

COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY . /app
COPY config/crontab /etc/cron.d/rake-cron

RUN chmod 0644 /etc/cron.d/rake-cron
RUN crontab /etc/cron.d/rake-cron

RUN bundle install --without test development staging

CMD /usr/bin/supervisord
