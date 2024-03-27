#!/bin/sh
set 
rm -f /app/tmp/*.pid /app/tmp/pids/*.pid tmp/*.sock
rm -rf tmp/cache/assets
bundle update eol_terms
bin/webpack
exec "$@"
