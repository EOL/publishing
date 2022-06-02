#!/bin/sh
rm -f /app/tmp/*.pid tmp/*.sock
rm -rf tmp/cache/assets
touch /tmp/supervisor.sock
chmod 777 /tmp/supervisor.sock
bundle update
bundle update eol_terms
rake assets:precompile
exec "$@"
