Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  #Devise Mailer settings.
  config.action_mailer.default_url_options = { host: 'localhost:3000' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Rails.application.secrets.smtp

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # locales for testing
  #config.i18n.available_locales = [:en, :mk]
end

# Keep failed jobs around so we can look at stacktraces
Delayed::Worker.destroy_failed_jobs = false

# NOTE: it does seem a *little* silly to me to move all of the secrets to the configuration, but I think that makes
# sense, because it allows people to bypass Secrets and use custom configs with their own environments, if need-be.
Rails.configuration.repository_url = Rails.application.secrets.repository['url']
Rails.configuration.eol_web_url = Rails.application.secrets.host['url']
Rails.configuration.x.image_path = Rails.application.secrets.image_path
Rails.configuration.traitbank_url = Rails.application.secrets.traitbank_url
