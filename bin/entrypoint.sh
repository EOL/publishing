#!/bin/sh
# NOTE: no bare `set` here -- it dumps every environment variable
# (including any secrets delivered as env vars) into the pod logs.
set -e

rm -f /app/tmp/*.pid /app/tmp/pids/*.pid /app/tmp/*.sock
rm -rf /app/tmp/cache/assets

# Load secrets delivered as mounted files: for any VAR_FILE pointing at a
# readable file, export VAR with the file's contents.
file_env() {
  var="$1"
  file_var="${var}_FILE"
  eval file_path="\${$file_var:-}"
  if [ -n "$file_path" ] && [ -f "$file_path" ]; then
    export "$var=$(cat "$file_path")"
  fi
}

file_env RAILS_MASTER_KEY
file_env TRAITBANK_URL
file_env NEO4J_USER
file_env NEO4J_PASSWORD
file_env SCOUT_APM_KEY

exec "$@"
