Recaptcha.configure do |config|
  config.site_key = Rails.configuration.creds.recaptcha_site_key
  config.secret_key = Rails.configuration.creds.recaptcha_secret_key
end
