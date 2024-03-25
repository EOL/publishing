Rails.application.configure do
  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true

  config.after_initialize do
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::INFO
  end

  config.cache_classes = false # We want them reloaded when they change:
  config.reload_classes_only_on_change = true
  # And we want polling to see when they change (this works better for docker)
  config.file_watcher = ActiveSupport::FileUpdateChecker
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.js_compressor = Uglifier.new(harmony: true)
  config.assets.compile = true
  config.active_storage.service = :local

  config.log_level = :warn
  config.log_tags = [ :request_id ]
  config.log_formatter = ::Logger::Formatter.new
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['PagesController#ping', 'ApiPingController#index', 'HomePageController#index']

  cache_addr = Rails.configuration.creds.cache_url
  config.cache_store = :mem_cache_store, cache_addr, { namespace: "EOL", compress: true }

  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = Rails.configuration.creds.host.symbolize_keys
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.configuration.creds.smtp.symbolize_keys
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.dump_schema_after_migration = false

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end
end

Rails.configuration.repository_url = Rails.configuration.creds.repository[:url]
Rails.configuration.eol_web_url = Rails.configuration.creds.host[:url]
Rails.configuration.x.image_path = Rails.configuration.creds.image_path
Rails.configuration.traitbank_url = Rails.configuration.creds.traitbank_url
Rails.configuration.git_version = `cd #{Rails.root} && git rev-parse HEAD`
