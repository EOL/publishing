Rails.application.configure do
  config.cache_classes = true
  cache_addr = Rails.application.secrets.cache_url
  config.cache_store = :dalli_store, cache_addr, { namespace: "EOL", compress: true }
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.action_mailer.default_url_options = Rails.application.secrets.host
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.application.secrets.smtp
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true
end

# NOTE: it does seem a *little* silly to me to move all of the secrets to the configuration, but I think that makes
# sense, because it allows people to bypass Secrets and use custom configs with their own environments, if need-be.
Rails.configuration.repository_url = Rails.application.secrets.repository['url']
Rails.configuration.eol_web_url = Rails.application.secrets.host['url']
Rails.configuration.x.image_path = Rails.application.secrets.image_path
Rails.configuration.traitbank_url = Rails.application.secrets.traitbank_url
