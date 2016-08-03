class Attribution < ActiveRecord::Base
  belongs_to :role, inverse_of: :attributions

  has_many :content_attributions
  has_many :contents, through: :content_attributions
end
