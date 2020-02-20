# This Role class is ONLY for use with references, NOT with permissions.
class Role < ApplicationRecord
  has_many :attributions, inverse_of: :role
end
