# unicorn-worker-killer wants these lines added BEFORE the require.
# Unicorn self-process killer
require 'unicorn/worker_killer'

# Max requests per worker
use Unicorn::WorkerKiller::MaxRequests, 1024, 2048

# Max memory size (RSS) per worker: 1 MB == 1048576 bytes
use Unicorn::WorkerKiller::Oom, (256*(1048576)), (512*(1048576))
# This file is used by Rack-based servers to start the application.
require ::File.expand_path('../config/environment', __FILE__)
run Rails.application