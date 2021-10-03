Rails.application.configure do
  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true

  config.after_initialize do
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::INFO
  end

  config.cache_classes = true
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

  cache_addr = Rails.application.secrets.cache_url
  config.cache_store = :mem_cache_store, cache_addr, { namespace: "EOL", compress: true }

  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = Rails.application.secrets.host.symbolize_keys
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.application.secrets.smtp.symbolize_keys
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.dump_schema_after_migration = false

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end
end

Rails.configuration.repository_url = Rails.application.secrets.repository[:url]
Rails.configuration.eol_web_url = Rails.application.secrets.host[:url]
Rails.configuration.x.image_path = Rails.application.secrets.image_path
Rails.configuration.traitbank_url = Rails.application.secrets.traitbank_url
Rails.configuration.git_version = `cd #{Rails.root} && git rev-parse HEAD`
