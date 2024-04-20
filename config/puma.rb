bind "tcp://0.0.0.0:#{ENV.fetch('PORT') { '3000' }}"
environment ENV.fetch('RAILS_ENV') { 'production' }

workers Integer(ENV.fetch('WEB_WORKERS') { 1 })
threads_count = Integer(ENV.fetch('WEB_THREADS') { 3 })
threads threads_count, threads_count

preload_app!

stdout_redirect(stdout = '/dev/stdout', stderr = '/dev/stderr', append = true)

rackup      DefaultRackup if defined?(DefaultRackup)
port        ENV['PORT']     || 3000
environment ENV['RAILS_ENV'] || 'development'