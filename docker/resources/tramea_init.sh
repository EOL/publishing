#!/bin/sh -e
APP="eol_website"

echo "Updating $APP.."
cd /u/apps/$APP && git pull

cp /u/apps/secrets.yml /u/apps/$APP/config/secrets.yml
/bin/bash -l -c 'cd /app/ && bundle'
/bin/bash -l -c 'cd /app/ && rake log:clear'
/bin/bash -l -c "cd /app && bundle exec unicorn -c /app/config/unicorn.rb -D"
service nginx start
