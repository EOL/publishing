def set_omniauth_hash(options = {})
 OmniAuth.config.mock_auth[options[:provider]] = OmniAuth::AuthHash.new({
      email: options[:email],
      name: options[:name],
      provider: options[:provider],
      uid: options[:uid] })
 auth = OmniAuth.config.mock_auth[options[:provider]] 
end
