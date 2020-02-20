class ImageInfo < ApplicationRecord
  belongs_to :image, class_name: "Medium", inverse_of: :image_info
end
