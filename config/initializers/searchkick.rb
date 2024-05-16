host = Redis.new(host: ENV.fetch("REDIS_HOST") { "redis" })
Searchkick.redis = ConnectionPool.new { host }
Searchkick.search_timeout = 3
Searchkick.timeout = 90 # This is, I assume, the timeout for non-searches, like reindexing.

# Reduce concurrency of reindex threads, we get overwhelmed:
ActiveJob::TrafficControl.client = Searchkick.redis

class Searchkick::BulkReindexJob
  concurrency 3
end