host = Redis.new(host: ENV.fetch("REDIS_URL") { "redis://redis:6379" })
begin
  host.ping
  Searchkick.redis = ConnectionPool.new { host }
rescue Redis::CannotConnectError
  # Nothing to do: we cannmot connect.
end
