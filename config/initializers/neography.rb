Neography.configure do |config|
  # Double the normal times: ...this isn't great for users, but it's great for admin. :S
  config.http_send_timeout    = 2400
  config.http_receive_timeout = 2400
end
