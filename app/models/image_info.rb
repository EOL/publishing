class ImageInfo < ActiveRecord::Base
  belongs_to :image, class_name: "Medium", inverse_of: :image_info
end
