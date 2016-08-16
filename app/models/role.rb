class Role < ActiveRecord::Base
  has_many :attributions, inverse_of: :role
end
