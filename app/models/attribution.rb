class Attribution < ActiveRecord::Base
  belongs_to :role, inverse_of: :attributions
  belongs_to :content, polymorphic: true
end
