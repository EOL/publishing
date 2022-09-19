#!/bin/sh
rm -f /app/tmp/*.pid tmp/*.sock
rm -rf tmp/cache/assets
touch /tmp/supervisor.sock
chmod 777 /tmp/supervisor.sock
bundle update
bundle update eol_terms
yarn upgrade > /app/log/assets.log 2>&1
/app/bin/webpack >> /app/log/assets.log 2>&1
rake assets:precompile >> /app/log/assets.log 2>&1
exec "$@"
