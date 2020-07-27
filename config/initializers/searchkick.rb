host = Redis.new(host: 'redis')
begin
  host.ping
  Searchkick.redis = ConnectionPool.new { host }
rescue Redis::CannotConnectError
  # Nothing to do: we cannmot connect.
end
