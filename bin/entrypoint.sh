#!/bin/sh
set 
rm -f /app/tmp/*.pid /app/tmp/pids/*.pid tmp/*.sock
rm -rf tmp/cache/assets
touch /tmp/supervisor.sock
chmod 777 /tmp/supervisor.sock
bundle update eol_terms
export NODE_OPTIONS='--openssl-legacy-provider npm run start'
/app/bin/webpack >> /app/log/assets.log 2>&1
rake assets:precompile >> /app/log/assets.log 2>&1
exec "$@"
