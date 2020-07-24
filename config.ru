# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)
run Rails.application

if ENV['RAILS_ENV'] == 'staging' ||  ENV['RAILS_ENV'] == 'production'
  require 'unicorn/worker_killer'

  too_many_requests_min =  500
  too_many_requests_max =  600

  # Max requests per worker
  use Unicorn::WorkerKiller::MaxRequests, too_many_requests_min, too_many_requests_max

  memory_oom_min = 2.gigabytes
  memory_oom_max = 2.5.gigabytes.to_i

  # Max memory size (RSS) per worker
  use Unicorn::WorkerKiller::Oom, memory_oom_min, memory_oom_max
end
