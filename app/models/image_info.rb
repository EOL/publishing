class ImageInfo < ActiveRecord::Base
  self.table_name = 'image_info'
  belongs_to :image, class_name: "Medium", inverse_of: :image_info
end
