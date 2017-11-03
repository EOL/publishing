class ImageInfo < ActiveRecord::Base
  set_table_name 'image_info'
  belongs_to :image, class_name: "Medium", inverse_of: :image_info
end
