# Really this max run time is ridiculous, but I don't ever want to hit it. We do real work and we watch the long-running
# jobs.
Delayed::Worker.max_run_time = 14.days
Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))
# It's possible that something went wrong with Delayed::Job, but, really, we don't *usually* want to re-try jobs. :\
Delayed::Worker.max_attempts = 2
Delayed::Worker.queue_attributes = {
  publish: { priority: 0 }
}

# NOTE: If you add another one of these, you should really move them to a jobs folder.
RepublishJob = Struct.new(:resource_id) do
  def perform
    Resource.find(resource_id).republish!
  end

  def queue_name
    'publish'
  end

  def max_attempts
    1
  end
end
