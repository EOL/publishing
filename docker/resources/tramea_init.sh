#!/bin/sh -e
APP="eol_website"

echo "Updating $APP.."
cd /u/apps/$APP && git pull

cp /u/apps/secrets.yml /u/apps/$APP/config/secrets.yml
/bin/bash -l -c 'cd /u/apps/eol_website/ && bundle'
/bin/bash -l -c 'cd /u/apps/eol_website/ && rake log:clear'
/bin/bash -l -c "cd /u/apps/eol_website && bundle exec unicorn -c /u/apps/eol_website/config/unicorn.rb -D"
service nginx start
