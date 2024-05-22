require_relative 'boot'

require 'rails/all'
require 'active_graph/railtie'

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
    config.time_zone = 'Eastern Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.available_locales = %i(en ar tr cs es pms fi de it mk pt-BR fr zh-TW zh-CN el nl uk)

    # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
    # the I18n.default_locale when a translation cannot be found).
    config.i18n.fallbacks = true

    config.exceptions_app = self.routes
    config.data_glossary_page_size = 250

    # Our credentials are environment-specific (for now; Rails 6 fixes this):
    config.creds = Rails.application.credentials[Rails.env.to_sym]

    config.repository_url = Rails.configuration.creds[:repository][:url]
    config.eol_web_url = Rails.configuration.creds[:host][:url]
    config.x.image_path = Rails.configuration.creds[:image_path]
    config.traitbank_url = ENV.fetch('TRAITBANK_URL') { "http://neo4j_username:password_here@neo4j:7474" }

    # For activenode/ruby-neo4j-driver gems, not neography
    config.neo4j.driver.url = ENV.fetch('NEO4J_DRIVER_URL') { "bolt://neo4j:7687" }
    config.neo4j.driver.username = ENV.fetch('NEO4J_USER') { "neo4j_username" }
    config.neo4j.driver.password = ENV.fetch('NEO4J_PASSWORD') { "password_here" }
    config.neo4j.driver.encryption = false

    # Search for classes in the lib directory
    config.autoload_paths += %W(#{config.root}/lib)
    config.eager_load_paths += %W(#{config.root}/lib) # NOTE: make sure this stays the same as autoload_paths!

    # set x-robots-tag header to noindex for all requests
    config.x.block_crawlers = Rails.configuration.creds[:block_crawlers] || false

    # disallowed prefixes for robots.txt and X-Robots-Tag header
    config.x.robots_disallow_patterns = [
      "/api/",
      "/users/",
      "/resources/*/nodes",
      "/search/",
      "/search?*",
      "/collected_pages/",
      "/pages/*/names",
      "/pages/*/data/",
      "/pages/*/trophic_web",
      "*?*" # Lots of arguments to all of the media tabs! Yeesh.
    ]
    config.i18n.available_locales.each do |locale|
      config.x.robots_disallow_patterns += [
        "/#{locale}/users/",
        "/#{locale}/resources/*/nodes",
        "/#{locale}/collected_pages/",
        "/#{locale}/pages/*/names",
        "/#{locale}/pages/*/data/",
        "/#{locale}/pages/*/trophic_web"
      ]
    end

    config.x.robots_slow_spiders = [
      "msnbot",
      "Baiduspider",
      "360Spider",
      "Yisouspider",
      "PetalBot",
      "Bytespider",
      "Sogou web spider",
      "Sogou inst spider"
    ]

    config.x.geonames_app_id = Rails.configuration.creds[:geonames_app_id]

    # scaffold config
    config.generators do |g|
      g.test_framework nil
      g.scaffold_stylesheet false
      g.javascript_engine :js
    end

    config.active_storage.service = :local
    app_host_name = Rails.configuration.creds[:host] &&
      Rails.configuration.creds[:host].key?(:name) ?
      Rails.configuration.creds[:host][:name] :
      'localhost:3001'
    Rails.application.routes.default_url_options[:host] = app_host_name 

    config.x.gbif_credentials = Rails.configuration.creds[:gbif_credentials]

    # point autocomplete to localized fields
    config.x.autocomplete_i18n_enabled = true
    config.active_job.queue_adapter = :sidekiq

    # neo4j log
    config.neo4j.logger = ActiveSupport::TaggedLogging.new(Logger.new(Rails.root.join('log', 'traitbank.log')))
    config.neo4j.logger.level = Logger::WARN
    config.neo4j.logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime} [#{severity}]: #{msg}\n"
    end
    config.neo4j.pretty_logged_cypher_queries = true
  end
end
