class Vernacular < ActiveRecord::Base
  belongs_to :language
  belongs_to :node, inverse_of: :vernaculars
  # DENORMALIZED:
  belongs_to :page, inverse_of: :vernaculars

  scope :preferred, -> { where(is_preferred: true) }
  scope :nonpreferred, -> { where(is_preferred: false) }
end
