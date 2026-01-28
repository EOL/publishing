source "https://rubygems.org"
# The REALLY basic stuff stays at the top:

gem 'rails', '6.1.7.7'
gem 'base64' # REMOVE THIS WHEN YOU UPDATE TO RAILS 7.
gem 'bigdecimal' # REMOVE THIS WHEN YOU UPDATE TO RAILS 7.
gem 'mutex_m' # REMOVE THIS WHEN YOU UPDATE TO RAILS 7.
gem 'csv' # REMOVE THIS WHEN YOU UPDATE TO RAILS 7.
gem 'drb' # REMOVE THIS WHEN YOU UPDATE TO RAILS 7. This one is needed for assets.
gem 'concurrent-ruby', '1.3.4' # REMOVE THIS WHEN YOU UPDATE TO RAILS 7.
# Use mysql2 as the database for Active Record
gem 'mysql2', '~> 0.5.6'
# Use puma as the web host
gem 'puma', '~> 6.4'

# "Internal" EOL gems:
gem 'eol_terms', git: 'https://github.com/EOL/eol_terms.git', branch: 'main'

# Asset-related gems next:
gem 'webpacker', '~> 6.0.0.beta'

# SASS
# Sass is end-of-life. Update to sassc gem: https://github.com/sass/sassc-ruby#readme
gem 'sass-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11.5'
# Use jquery as the JavaScript library TODO ... I don't think we do, anymore?
gem 'jquery-rails', '~> 4.4'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 4.2'

# Pagination with kaminari. It's out of order because the methods it uses need
# to be defined first for other classes to recognize them:
gem 'kaminari', '~> 1.2.2'

# All other non-environment-specific gems come next.
#
# ALPHABETICALLY, PLEASE.
#
# ...and with a comment above each gem (or block of related gems) explaining what it's for. Let's keep this
# maintainable!

gem 'activegraph', '~> 10.1'
# TEMP! ...when you change activegraph or update gems, remove this, it's a security bump.
gem 'activestorage', '~> 6.1'
gem 'neo4j-ruby-driver', git: 'https://github.com/EOL/neo4j-ruby-driver.git', branch: '1.7'

# For bulk inserts:
gem 'activerecord-import', '~> 1.3'
# Acts As List simplifies ordered lists of models:
gem 'acts_as_list', '~> 1.0'
# Faster startup:
gem 'bootsnap', '~> 1.10', require: false
# Counter Culture handles cached counts of things (which we use ALL OVER):
gem 'counter_culture', '~> 2.9'
# Cron jobs:
gem 'crono', '~> 2.0'
# Run background jobs:
gem 'daemons', '~> 1.4'
# Memcached (not for development):
gem 'dalli', '~> 2.7'
# Background jobs (to be run by daemons, q.v.):
gem 'delayed_job', '~> 4.1'
gem 'delayed_job_active_record', '~> 4.1'
# Devise handles authentication and some authorization:
gem 'devise', '~> 4.9'
gem 'devise-i18n-views', '~> 0.3'
gem 'devise-encryptable', '~> 0.2'
# Discourse handles comments and chat: TODO: do we even use this anymore?!
gem 'discourse_api', '~> 0.48'
# Model decoration
gem 'draper', '~> 4.0'
# ElasticSearch via SearchKick:
gem 'elasticsearch', '~> 8.8' # Needs to stay in sync with the version of ES that we're using
gem 'searchkick', '~> 5.3' # Needs to stay in sync (ish) with the elasticsearch gem.
# url slug support
gem 'friendly_id', '~> 5.4'
# Icons
gem 'font-awesome-sass', '~> 5.15'
# This is used to locally have a copy of Open Sans. IF YOU STOP USING OPEN SANS (note the space), YOU SHOULD REMOVE THIS GEM!
gem 'font-kit-rails', '~> 1.2'
# jwt is used for JSON Web Token (JWT) standard API handshakes. ...This WAS included in Omniauth, which we removed.
gem 'jwt', '~> 2.2' # Note the gem is ruby-jwt
# Because ERB is just plain silly compared to Haml:
gem 'haml', '~> 5.2.1'
gem 'haml-rails', '~> 2.0.1'
# HTTP client
gem 'http', '~> 5.0'
# translations in JS
gem 'i18n-js', '~> 3.9' # NOTE: Version 4 is coming. There is no documentation for it as yet, but be mindful.
# JSON schema-based validation
gem 'json_schemer', '~> 0.2'
# QUIET PLEASE MAKE IT STOP! This helps us cull some of the noise in the logs:
gem 'lograge', '~> 0.14'
# This should help stop some of the warnings you'll see in the logs/console:
gem 'net-http'
# Speed up JSON, including for ElasticSearch:
gem 'oj', '~> 3.13'
# Debugging:
gem 'pry-rails' # NOT specifying a version for this; latest is best.
# Authorization:
gem 'pundit', '~> 2.1'
# CORS middleware, we need this for HW's cross-site API requests:
gem 'rack-cors'
# Turing test:
gem 'recaptcha', '~> 5.8', require: 'recaptcha/rails'
# Zip file support ; NOTE: this is almost up to version 3.0, and then it will have some interface changes that we need
# to switch to. Read https://github.com/rubyzip/rubyzip when the time comes!
gem 'redis', '~> 5.0'
gem 'rubyzip', '~> 2.3'
# Searchkick uses sidekiq for job processing (really, anything BUT Delayed::Job, apparently), so I've installed it:
gem 'sidekiq', '~> 6.5'
# OUT OF ORDER: Sidekiq needs AJ-TC to reduce concurrency https://github.com/ankane/searchkick?tab=readme-ov-file#filterable-fields
gem "activejob-traffic_control", ">= 0.1.3"
# Simplify Forms:
# KEEPING client_side_validations OUT OF ORDER, since they are tightly bound to simple_form;
# these are ONLY used on the user page, in the user_helper's validate: true clause...
# TODO: I am not sure these are working / used anymore. Check and remove, if not.
gem 'simple_form', '~> 5.1'
gem 'client_side_validations', '~> 18.1'
gem 'client_side_validations-simple_form', '~> 13'
#Sitemap
gem 'sitemap_generator', '~> 6.2'
# Speed up ElasticSearch ... but also good if you want to do web requests, see https://github.com/typhoeus/typhoeus
gem 'typhoeus', '~> 1.4'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', '~> 11'
  gem 'solargraph' # For VS Code
  gem 'solargraph-rails' # For VS Code
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 3'
end
