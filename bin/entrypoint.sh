#!/bin/sh
rm -f /tmp/*.pid /tmp/*.sock
rm -rf /tmp/cache/assets
bundle install
bundle update eol_terms
rake assets:precompile
exec "$@"
