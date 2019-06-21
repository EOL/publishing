# This file is meant to load gems (including those specific to the environment)
# and to configure the application. You PROBABLY want to add configuration here.
require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'neo4j/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EolWebsite
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :fr]
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.available_locales = [:en]

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true
    config.exceptions_app = self.routes
    config.data_glossary_page_size = 250

    config.middleware.insert_before 0, "Rack::Cors" do
      allow do
        origins '*'
        resource '/api/*', headers: :any, methods: [:get, :post, :options]
      end
    end

    # For neo4j gem, not usual neography access
    config.neo4j.session.type = :http
    config.neo4j.session.url = Rails.application.secrets.traitbank_url

    # Search for classes in the lib directory
    config.autoload_paths += %W(#{config.root}/lib)
    
    # set x-robots-tag header to noindex for all requests
    config.x.block_crawlers = Rails.application.secrets.block_crawlers || false

    # disallowed prefixes for robots.txt and X-Robots-Tag header
    config.x.robots_disallow_patterns = [
      "/api/",
      "/users/",
      "/resources/*/nodes/",
    ]

  end
end
