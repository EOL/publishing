#!/bin/sh
rm -f rm -f /tmp/*.pid /tmp/*.sock
bundle install
bundle update eol_terms
rake assets:precompile
exec "$@"
