class ImageInfo < ApplicationRecord
  belongs_to :image, class_name: "Medium", inverse_of: :image_info, foreign_key: :medium_id
end
