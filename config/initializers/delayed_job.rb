# Jun 2022: We had this set to 24 hours because a week was too long and "overnight" seemed reasonaable. But we slowed
# down the rate at which traits are ingested (b/c it was failing at faster rates) and now BIG jobs can take a few days!
Delayed::Worker.max_run_time = 4.days
Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))
# It's possible that something went wrong with Delayed::Job, but, really, we don't *usually* want to re-try jobs. :\
Delayed::Worker.max_attempts = 2
Delayed::Worker.queue_attributes = {
  harvest: { priority: 0 }
}
Delayed::Worker.raise_signal_exceptions = :term # unlock jobs on SIGTERM so that they can be picked up by the next available worker

# NOTE: If you add another one of these, you should really move them to a jobs folder.
RepublishJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Rails.logger.warn("Publishing resource [#{resource.name}](#{ENV.fetch('EOL_PUBLISHING_URL') { 'https://eol.org' }}/resources/#{resource.id})")
    resource.publish
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

RepublishTraitsJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Rails.logger.warn("Re-publishing TRAITS ONLY for resource [#{resource.name}](#{ENV.fetch('EOL_PUBLISHING_URL') { 'https://eol.org' }}/resources/#{resource.id})")
    resource.republish_traits
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

RemoveTraitContentJob = Struct.new(:resource_id, :stage, :size, :republish) do
  def perform
    resource = Resource.find(resource_id)
    Rails.logger.warn("Removing TraitBank data (stage: #{stage}) for resource #{resource.log_string}")
    Rails.logger.warn("...will #{republish ? '' : 'NOT'} republish when complete (#{republish})")
    TraitBank::Admin.remove_by_resource(resource, stage, size, republish)
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

ReindexJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Rails.logger.warn("Reindexing resource [#{resource.name}](#{ENV.fetch('EOL_PUBLISHING_URL') { 'https://eol.org' }}/resources/#{resource.id})")
    # TODO: there are likely other things to do, here, but this is what we need now.
    resource.fix_missing_page_contents
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end

FixNoNamesJob = Struct.new(:resource_id) do
  def perform
    resource = Resource.find(resource_id)
    Rails.logger.warn("Fixing names for resource [#{resource.name}](#{ENV.fetch('EOL_PUBLISHING_URL') { 'https://eol.org' }}/resources/#{resource.id})")
    # TODO: there are likely other things to do, here, but this is what we need now.
    resource.fix_no_names
  end

  def queue_name
    'harvest'
  end

  def max_attempts
    1
  end
end
