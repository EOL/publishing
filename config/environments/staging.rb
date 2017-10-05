Rails.application.configure do
  config.cache_classes = true
  cache_addr = ENV["EOL_STAGING_CACHE_URL"] || "memcached:11211"
  config.cache_store = :dalli_store, cache_addr, { namespace: "EOL", compress: true }
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  # TODO: set up mailing...
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = { address: 'localhost', port: 1025}
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.assets.debug = false
  config.assets.digest = true
  config.assets.raise_runtime_errors = true
end

Rails.configuration.repository_url = 'https://beta-repo.eol.org'
