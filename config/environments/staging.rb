Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.ignore_actions = ['PagesController#ping', 'ApiPingController#index', 'HomePageController#index']
  config.cache_classes = false # We want them reloaded when they change:
  config.reload_classes_only_on_change = true
  # And we want polling to see when they change (this works better for docker)
  config.file_watcher = ActiveSupport::FileUpdateChecker
  cache_addr = Rails.configuration.creds[:cache_url]
  config.cache_store = :mem_cache_store, cache_addr, { namespace: "EOL_stage", compress: true }
  config.eager_load = true
  config.consider_all_requests_local = false
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

# NOTE: it does seem a *little* silly to me to move all of the secrets to the configuration, but I think that makes
# sense, because it allows people to bypass Secrets and use custom configs with their own environments, if need-be.
Rails.configuration.repository_url = Rails.configuration.creds[:repository][:url]
Rails.configuration.eol_web_url = Rails.configuration.creds[:host][:url]
Rails.configuration.x.image_path = Rails.configuration.creds[:image_path]
Rails.configuration.traitbank_url = Rails.configuration.creds[:traitbank_url]
