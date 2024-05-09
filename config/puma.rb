bind "tcp://0.0.0.0:#{ENV.fetch('PORT') { '3000' }}"
environment ENV.fetch('RAILS_ENV') { 'production' }

workers Integer(ENV.fetch('WEB_WORKERS') { 3 })
threads_count = Integer(ENV.fetch('WEB_THREADS') { 5 })
threads threads_count, threads_count

preload_app!

stdout_redirect(stdout = '/dev/stdout', stderr = '/dev/stderr', append = true)

rackup      DefaultRackup if defined?(DefaultRackup)
port        ENV['PORT']     || 3000
environment ENV['RAILS_ENV'] || 'development'

on_worker_boot do
  puts "Worker booting..."
  if defined?(ActiveGraph::Base)
    config = Rails.application.config.neo4j.driver
    ActiveGraph::Base.driver = Neo4j::Driver::GraphDatabase.driver(
      config.url,
      Neo4j::Driver.AuthTokens.basic(config.username, config.password),
      encryption: config.encryption
    )
  end
end