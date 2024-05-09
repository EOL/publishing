require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true

  config.after_initialize do
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::INFO
  end

  config.cache_classes = true
  # And we want polling to see when they change (this works better for docker)
  config.file_watcher = ActiveSupport::FileUpdateChecker
  config.eager_load = true
  config.consider_all_requests_local = false
  config.require_master_key = true
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.js_compressor = Uglifier.new(harmony: true)
  config.assets.compile = true
  config.active_storage.service = :local

  config.i18n.fallbacks = true
  
  config.log_level = :warn
  config.log_tags = [ :request_id ]
  config.log_formatter = ::Logger::Formatter.new
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['PagesController#ping', 'ApiPingController#index', 'HomePageController#index']
  config.active_support.disallowed_deprecation = :log

  cache_addr = ENV.fetch('CACHE_URL') { 'memcached:11211' }
  config.cache_store = :mem_cache_store, cache_addr, { namespace: "EOL_prod", compress: true }

  config.action_dispatch.default_headers.merge!({ 'X-Frame-Options' => 'ALLOWALL' })
  
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = Rails.configuration.creds[:host].symbolize_keys
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.configuration.creds[:smtp].symbolize_keys
  config.active_record.migration_error = :page_load
  config.active_record.dump_schema_after_migration = false

  logger           = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = config.log_formatter
  config.logger    = ActiveSupport::TaggedLogging.new(logger)

  config.git_version = `cd #{Rails.root} && git rev-parse HEAD`
end
