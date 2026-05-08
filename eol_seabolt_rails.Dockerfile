FROM ruby:3.3.1-bullseye AS seabolt-builder
# Note that this ruby version is based off of debian 11, rather than 12, because Seabolt fails on 12.
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

ARG SEABOLT_PACKAGE_VERSION=1.7.4

RUN apt-get update -q && \
    apt-get install -qq -y --no-install-recommends build-essential ca-certificates cmake git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN git clone --depth 1 https://github.com/neo4j-drivers/seabolt.git /seabolt && \
    cd /seabolt && \
    ./make_debug.sh && \
    cd build && \
    cpack && \
    mkdir /seabolt-package && \
    tar xzf "/seabolt/build/dist-package/seabolt-${SEABOLT_PACKAGE_VERSION}-dev-Linux-debian-11.tar.gz" -C /seabolt-package --strip-components=1

# -=-=-=-=-=-=-

FROM ruby:3.3.1-bullseye
# Note that this ruby version is based off of debian 11, rather than 12, because Seabolt fails on 12.
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

WORKDIR /app

RUN apt-get update -q && \
    apt-get install -qq -y --no-install-recommends build-essential libpq-dev curl wget git openssh-server openssh-client \
      apache2-utils procps vim logrotate msmtp gnupg ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /etc/ssmtp

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update -q && \
    apt-get install -qq -y --no-install-recommends nodejs && \
    npm install -g --no-fund yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set up mail (for user notifications, which are rare but critical)
# root is the person who gets all mail for userids < 1000
# Here is the gmail configuration (or change it to your private smtp server)
RUN printf '%s\n' \
    'root=admin@eol.org' \
    'mailhub=smtp-relay.gmail.com:25' \
    'UseTLS=YES' \
    'UseSTARTTLS=YES' \
    >> /etc/ssmtp/ssmtp.conf

COPY --from=seabolt-builder /seabolt-package/ /
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/seabolt.conf && ldconfig
