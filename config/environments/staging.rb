Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['PagesController#ping', 'ApiPingController#index', 'HomePageController#index']
  config.cache_classes = false # We want them reloaded when they change:
  config.reload_classes_only_on_change = true
  # And we want polling to see when they change (this works better for docker)
  config.file_watcher = ActiveSupport::FileUpdateChecker
  cache_addr = ENV.fetch('CACHE_URL') { 'memcached:11211' }
  config.cache_store = :mem_cache_store, cache_addr, { namespace: "EOL_stage", compress: true }
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_dispatch.default_headers.merge!({ 'X-Frame-Options' => 'ALLOWALL' })

  config.action_controller.perform_caching = true
  config.action_mailer.default_url_options = Rails.configuration.creds[:host].symbolize_keys
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.configuration.creds[:smtp].symbolize_keys
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  
  config.log_level = :info

  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true

  logger           = Logger.new(STDOUT)
  logger.formatter = config.log_formatter
  config.logger    = ActiveSupport::TaggedLogging.new(logger)
end

