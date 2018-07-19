require 'jwt'

# Not an ActiveRecord; not instantiated, actually

class TokenAuthentication
  belongs_to :user
  def self.encode(payload)
    JWT.encode(payload, Rails.application.secrets.json_web_token_secret)
  end

  def self.decode(token)
    JWT.decode(token, Rails.application.secrets.json_web_token_secret)
  end
end
