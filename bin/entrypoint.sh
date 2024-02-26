#!/bin/sh
set 
rm -f /app/tmp/*.pid tmp/*.sock
rm -rf tmp/cache/assets
touch /tmp/supervisor.sock
chmod 777 /tmp/supervisor.sock
gem install `tail -n 1 Gemfile.lock | sed 's/^\s\+/bundler:/'`
bundle update
bundle update eol_terms
export NODE_OPTIONS='--openssl-legacy-provider npm run start'
yarn upgrade > /app/log/assets.log 2>&1
/app/bin/webpack >> /app/log/assets.log 2>&1
yarn install > /app/log/assets.log 2>&1
rake assets:precompile >> /app/log/assets.log 2>&1
exec "$@"
