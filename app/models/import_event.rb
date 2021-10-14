class ImportEvent < ApplicationRecord
  belongs_to :import_log, inverse_of: :import_events

  enum cat: %i[infos warns errors starts ends urls updates]

  scope :warns, -> { where(cat: ImportEvent.cats[:warns]) }
end
