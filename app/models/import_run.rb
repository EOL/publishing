class ImportRun < ApplicationRecord
  # nothing but timestamps (including completed_at)
  scope :completed, -> { where("completed_at IS NOT NULL") }

  # NOTE: An alias for starting a publish manually.
  def self.now(resource)
    Publishing::Fast.by_resource(Resource.last)
  end

  def self.all_clear!
    ImportRun.where(completed_at: nil).update_all(completed_at: Time.now)
    ImportLog.where(completed_at: nil, failed_at: nil).update_all(failed_at: Time.now, status: 'failed')
  end
end
