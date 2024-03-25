require 'jwt'

# Not an ActiveRecord; not instantiated, actually

class TokenAuthentication
  def self.encode(payload)
    JWT.encode(payload, Rails.application.credentials.json_web_token_secret)
  end

  def self.decode(token)
    JWT.decode(token, Rails.application.credentials.json_web_token_secret)
  end
end
