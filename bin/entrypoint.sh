#!/bin/sh
rm -f rm -f /tmp/*.pid /tmp/*.sock
rake assets:precompile
exec "$@"
