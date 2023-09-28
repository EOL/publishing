Sidekiq.configure_server do |config|
  config.redis = { url: "localhost:6379" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "localhost:6379" }
end
