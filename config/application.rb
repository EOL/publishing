require_relative 'boot'

require 'rails/all'
require 'neo4j/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EolWebsite
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
        # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    # you also have to modify config/initalizers/refinery/i18n.rb if you want to enable a new locale :(
    config.i18n.available_locales = %i(en mk fi pt-BR fr zh-TW pms tr)

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
      "/search/"
    ]

    config.x.geonames_app_id = Rails.application.secrets.geonames_app_id
  end
end
