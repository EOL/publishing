FROM ruby:3.3.1-bullseye
# Note that this ruby version is based off of debian 11, rather than 12, because Seabolt fails on 12.
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

RUN apt-get update -q && \
    apt-get install -qq -y build-essential libpq-dev curl wget openssh-server openssh-client \
    apache2-utils procps vim logrotate msmtp gnupg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /etc/ssmtp

COPY . /app

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - &&\
    apt-get install -y nodejs
RUN apt-get update -q && \
    apt-get install -qq -y nodejs && \
    npm install -g --no-fund yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set up mail (for user notifications, which are rare but critical)
# root is the person who gets all mail for userids < 1000
RUN echo "root=admin@eol.org" >> /etc/ssmtp/ssmtp.conf
# Here is the gmail configuration (or change it to your private smtp server)
RUN echo "mailhub=smtp-relay.gmail.com:25" >> /etc/ssmtp/ssmtp.conf

RUN echo "UseTLS=YES" >> /etc/ssmtp/ssmtp.conf
RUN echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf

RUN apt-get update -q && \
    apt-get install -qq -y cmake

RUN cd / && git clone https://github.com/neo4j-drivers/seabolt.git && \
    cd seabolt && ./make_debug.sh && cd build && cpack
RUN cd / && \
    tar xzf /seabolt/build/dist-package/seabolt-1.7.4-dev-Linux-debian-11.tar.gz && \
    cp -rf seabolt-1.7.4-dev-Linux-debian-11/* .
