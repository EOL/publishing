host = Redis.new(host: ENV.fetch("REDIS_HOST") { "redis" })
begin
  host.ping
  Searchkick.redis = ConnectionPool.new { host }
rescue Redis::CannotConnectError
  # Nothing to do: we cannmot connect.
end
