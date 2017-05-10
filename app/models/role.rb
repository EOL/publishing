# This Role class is ONLY for use with references, NOT with permissions.
class Role < ActiveRecord::Base
  has_many :attributions, inverse_of: :role
end
