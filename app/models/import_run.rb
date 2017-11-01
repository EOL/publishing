class ImportRun < ActiveRecord::Base
  # nothing but timestamps (including completed_at)

  scope :completed, -> { where("completed_at IS NOT NULL") }
end
