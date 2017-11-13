class ImportRun < ActiveRecord::Base
  # nothing but timestamps (including completed_at)
  scope :completed, -> { where("completed_at IS NOT NULL") }

  # NOTE: shorthand for starting an import manually. Easier to type ImportRun.now than this other thing:
  def self.now
    Import::Repository.start
  end
end
