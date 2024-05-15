host = Redis.new(host: ENV.fetch("REDIS_HOST") { "redis" })
Searchkick.redis = ConnectionPool.new { host }
Searchkick.search_timeout = 3
Searchkick.timeout = 90 # This is, I assume, the timeout for non-searches, like reindexing.