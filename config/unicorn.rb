app_dir = "/app"

working_directory app_dir

pid "#{app_dir}/tmp/unicorn.pid"

stderr_path "#{app_dir}/log/unicorn.stderr.log"
# STDOUT turns out to be pretty useless: it just prints "{:join=>", ", :open=>"(", :close=>")"}" over and over. :|
# NOTE: the default, if missing, is /dev/null ...which we want in this case.
# stdout_path "#{app_dir}/log/unicorn.stdout.log"

worker_processes ENV['WORKER_PROCESSES'].to_i
# listen "#{app_dir}/tmp/unicorn.sock", :backlog => 1024
listen "128.0.0.1:3001"
timeout 905 # Setting this HIGHER than unicorn, so that we don't reap processes unless we have to.

preload_app true
GC.respond_to?(:copy_on_write_friendly=) && GC.copy_on_write_friendly = true

# Close connections in before_fork, establish them in after_fork (for use with preload_app)
# Nothing needed for Sidekiq per https://github.com/mperham/sidekiq/blob/master/Changes.md#290
# Nothing needed for Dalli (memcached) per https://github.com/petergoldstein/dalli#features-and-changes
# Unsure if ActiveGraph disconnect/reconnect is necessary, but I think it's a good idea
before_fork do |server, worker|
  defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.disconnect!
  defined?(ActiveGraph::Base) && ActiveGraph::Base.driver&.close
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) && ActiveRecord::Base.establish_connection
  
  if defined?(ActiveGraph::Base)
    config = Rails.application.config.neo4j.driver
    ActiveGraph::Base.driver = Neo4j::Driver::GraphDatabase.driver(
      config.url,
      Neo4j::Driver::AuthTokens.basic(config.username, config.password),
      encryption: config.encryption
    )
  end
end
