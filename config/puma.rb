bind "tcp://0.0.0.0:#{ENV.fetch('PORT') { '3000' }}"
environment ENV.fetch('RAILS_ENV') { 'production' }

workers Integer(ENV['WEB_CONCURRENCY'] || 4)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

stdout_redirect(stdout = '/dev/stdout', stderr = '/dev/stderr', append = true)

rackup      DefaultRackup if defined?(DefaultRackup)
port        ENV['PORT']     || 3000
environment ENV['RAILS_ENV'] || 'development'