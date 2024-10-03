bind "tcp://0.0.0.0:#{ENV.fetch('PORT') { '3000' }}"
environment ENV.fetch('RAILS_ENV') { 'production' }

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

workers Integer(ENV.fetch('WEB_WORKERS') { 3 })
threads_count = Integer(ENV.fetch('WEB_THREADS') { 5 })
threads threads_count, threads_count

preload_app!

stdout_redirect(stdout = '/dev/stdout', stderr = '/dev/stderr', append = true)

rackup      DefaultRackup if defined?(DefaultRackup)
port        ENV['PORT']     || 3000
environment ENV['RAILS_ENV'] || 'development'