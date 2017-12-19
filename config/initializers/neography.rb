Neography.configure do |config|
  # Quadruple the normal times: ...this isn't great for users, but it's great for admin. :S
  config.http_send_timeout    = 4800
  config.http_receive_timeout = 4800
end
