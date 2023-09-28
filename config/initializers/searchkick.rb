host = Redis.new(host: 'localhost:6379')
begin
  host.ping
  Searchkick.redis = ConnectionPool.new { host }
rescue Redis::CannotConnectError
  # Nothing to do: we cannmot connect.
end
