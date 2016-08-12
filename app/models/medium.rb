class Medium < ActiveRecord::Base
  include Content
  include Content::Attributed

  has_one :image_info, inverse_of: :image
end
