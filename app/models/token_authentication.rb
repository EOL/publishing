require 'jwt'

# Not an ActiveRecord; not instantiated, actually

class TokenAuthentication
  def self.encode(payload)
    JWT.encode(payload, Rails.configuration.creds[:json_web_token_secret])
  end

  def self.decode(token)
    JWT.decode(token, Rails.configuration.creds[:json_web_token_secret])
  end
end
