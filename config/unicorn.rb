app_dir = "/u/apps/eol_website"

working_directory app_dir

pid "#{app_dir}/tmp/unicorn.pid"

stderr_path "#{app_dir}/log/unicorn.stderr.log"
stdout_path "#{app_dir}/log/unicorn.stdout.log"

worker_processes ENV["EOL_UNICORN_WORKER_PROCESSES"].to_i
listen "#{app_dir}/tmp/unicorn.sock", :backlog => 64
timeout 240
