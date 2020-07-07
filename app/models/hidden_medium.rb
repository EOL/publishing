class HiddenMedium < ApplicationRecord
  belongs_to :medium

  validates :medium_id, uniqueness: true, presence: true
  validates_presence_of :resource_pk
  validates_presence_of :resource_id
end
