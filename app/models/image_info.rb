class ImageInfo < ActiveRecord::Base
  belongs_to :image, class: "Medium", inverse_of: :image_info
end
