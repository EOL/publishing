source 'https://rubygems.org'

# The REALLY basic stuff stays at the top:

gem 'rails', '5.2.4.1'
# Use mysql2 as the database for Active Record
gem 'mysql2', '0.5.3'

# Asset-related gems next:

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.10'
# Use jquery as the JavaScript library TODO ... I don't think we do, anymore?
gem 'jquery-rails', '~> 4.3'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 1.0', group: :doc
# javascript code from rails TODO: I don't think we want this, but could be wrong.
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 4.2'
# RefineryCMS
gem 'refinerycms', git: "https://github.com/refinery/refinerycms", ref: "81ed991"
gem 'refinerycms-wymeditor', '2.2.0'
gem 'refinerycms-i18n', '5.0.1'

# Use Unicorn as the app server. Not *strictly* required, but handy for development... and what we use in production
# anyway.
gem 'unicorn', '~> 5.5'

# Pagination with kaminari. It's out of order because the methods it uses need
# to be defined first for other classes to recognize them:
gem 'kaminari', '~> 1.2'

# All other non-environment-specific gems come next.
#
# ALPHABETICALLY, PLEASE.
#
# ...and with a comment above each gem (or block of related gems) explaining what it's for. Let's keep this
# maintainable!

# For bulk inserts:
gem 'activerecord-import', '~> 1.0'
# Acts As List simplifies ordered lists of models:
gem 'acts_as_list', '~> 1.0'
# Faster startup:
gem 'bootsnap', '~> 1.4', require: false
# Counter Culture handled cached counts of things (which we use ALL OVER):
gem 'counter_culture', '~> 2.3'
# Cron jobs:
gem 'crono', '~> 1.1'
# Run background jobs:
gem 'daemons', '~> 1.3'
# Memcached (not for development):
gem 'dalli', '~> 2.7'
# Background jobs (to be run by daemons, q.v.):
gem 'delayed_job'
gem 'delayed_job_active_record'
# Devise handles authentication and some authorization:
gem 'devise'
gem 'devise-i18n-views'
gem 'devise-encryptable'
# Discourse handles comments and chat:
gem 'discourse_api'
# Model decoration
gem 'draper', '~> 4' # NOTE: 3.1 was the version we were using... Forced an update of nokogiri (but just a minor rev)
# Icons
gem 'font-awesome-sass', '~> 4.3'
# This is used to locally have a copy of OpenSans. IF YOU STOP USING OPENSANS, YOU SHOULD REMOVE THIS GEM!
gem 'font-kit-rails'
# jwt is used for JSON Web Token (JWT) standard API handshakes. ...This WAS included in Omniauth, which we removed.
gem 'jwt'
# Because ERB is just plain silly compared to Haml:
gem 'haml-rails'
# QUIET PLEASE MAKE IT STOP:
gem 'lograge'
# Neography is used for our Triple Store for now:
gem 'neography'
# Site monitoring for staging and production:
gem 'newrelic_rpm'
# Speed up JSON, including for ElasticSearch:
gem 'oj'
# Debugging:
gem 'pry-rails'
# Authorization:
gem 'pundit'
# Enable CORS (see config/application for specifics):
gem 'rack-cors', require: 'rack/cors'
# Turing test:
gem 'recaptcha', require: 'recaptcha/rails'
# Zip file support
gem 'rubyzip'
# ElasticSearch via SearchKick:
gem 'searchkick'
gem 'elasticsearch', '~> 6'
# Simplify Forms:
gem 'simple_form'
# KEEPING THESE OUT OF ORDER, since they are tightly bound to simple_form
# These are ONLY used on the user page, in the user_helper's validate: true clause...
gem 'client_side_validations'
gem 'client_side_validations-simple_form'

# Speed up ElasticSearch ... but also good if you want to do web requests, see https://github.com/typhoeus/typhoeus
gem 'typhoeus'
# OGM (object graph mapper for Neo4J). Added for use with searchkick.
gem 'neo4j', '~> 9.4'
# Sitemap
gem 'sitemap_generator'
# url helpers in JS
gem 'js-routes'
#http client
gem "http"

group :development, :test do
  gem 'active_record_query_trace'
  # Security analysis:
  gem 'brakeman', :require => false
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  # Coveralls tracks our spec coverage:
  gem 'coveralls', require: false
  # Rails told me to add this to my development group. I don't know why, but I'm ... listening.
  gem 'listen'
  # Rubocop... which technically you want on your *system*, but ...
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  # Simplecov, oddly, to add configuration for Coveralls.
  gem 'simplecov'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  #for simulating confirmation mails
  gem 'mailcatcher'

  # For benchmarking queries:
  gem 'meta_request'

  gem 'i18n-tasks'
end

group :test do
  gem 'rspec-rails', '~> 3.8'
  gem 'better_errors'
  gem 'capybara'
  gem 'factory_girl'
  gem 'faker'
  gem 'rack_session_access'
  gem 'shoulda-matchers', '~> 3.1'
end
