class Medium < ActiveRecord::Base
  include Content::Attributed

  has_one :image_info, inverse_of: :image
end
