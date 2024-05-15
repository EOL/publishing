host = Redis.new(host: ENV.fetch("REDIS_HOST") { "redis" })
begin
  host.ping
  Searchkick.redis = ConnectionPool.new { host }
rescue Redis::CannotConnectError
  # Nothing to do: we cannmot connect.
end

Searchkick.search_timeout = 3
Searchkick.timeout = 90 # This is, I assume, the timeout for non-searches, like reindexing.