class ImportRun < ActiveRecord::Base
  # nothing but timestamps (including completed_at)
  scope :completed, -> { where("completed_at IS NOT NULL") }

  # NOTE: An alias for starting a publish manually.
  def self.now
    Publishing.start
  end
end
