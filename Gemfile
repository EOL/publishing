source 'https://rubygems.org'

# The REALLY basic stuff stays at the top:

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.7.1'
# Use mysql2 as the database for Active Record
gem 'mysql2'

# Asset-related gems next:

# We're using Angular for our interactive client side stuff:
gem 'angularjs-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# Use jquery as the JavaScript library TODO ... I don't think we do, anymore?
gem 'jquery-rails'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc
#Use sunspot to work with solr
gem 'sunspot_rails', '~> 2.2.5'
# javascript code from rails TODO: I don't think we want this, but could be wrong.
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# RefineryCMS
gem 'refinerycms'
gem 'refinerycms-wymeditor'
gem 'refinerycms-ckeditor'
gem 'refinerycms-i18n'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# All other non-environment-specific gems come next. ALPHABETICALLY, PLEASE.
# ..and with a comment above each gem (or block of related gems) explaining what
# it's for. Let's keep this maintainable!

# Acts As List simplifies ordered lists of models:
gem 'acts_as_list', '~> 0.7.6'
# Nested set for Node:
gem 'awesome_nested_set', '~> 3.0.0'
# Counter Culture handled cached counts of things (which we use ALL OVER):
gem 'counter_culture', '~> 0.1.33'
# Devise handles authentication and some authorization:
gem 'devise','4.2.0'
gem 'devise-i18n-views'
gem 'devise-encryptable'
# Because ERB is just plain silly compared to Haml:
gem 'haml-rails'
# Neography is used for our Triple Store for now:
gem "neography", "~> 1.8"
# OpenAuth logins from our preferred sources:
gem 'omniauth-facebook'
gem 'omniauth-twitter'
gem 'omniauth-google-oauth2'
gem 'omniauth-yahoo'
# Handle attachments (icons):
gem "paperclip", "~> 5.1"
# Authorization:
gem "pundit", "~> 1.1"
# Turing test:
gem 'recaptcha', require: 'recaptcha/rails'
gem 'angular_rails_csrf'
# Pagination:
gem "kaminari", "~> 1.0"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  # Coveralls tracks our spec coverage:
  gem 'coveralls', require: false
  # Progress bar for indexing solr items:
  gem 'progress_bar', '~> 1.0.5'
  # Simplecov, oddly, to add configuration for Coveralls.
  gem "simplecov", "~> 0.12"
  #solr package. This is gonna be used in development and test environments
  gem "sunspot_solr", '~> 2.2.5'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  #for simulating confirmation mails
  gem 'mailcatcher'
end

group :test do
  gem 'rspec-rails'

  gem 'better_errors'
  gem 'capybara'
  gem 'factory_girl'
  gem 'faker'
  gem 'rack_session_access'
end
