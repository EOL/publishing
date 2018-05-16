class CollectedPagesMedium < ActiveRecord::Base
  belongs_to :collected_page
  belongs_to :medium, inverse_of: :collected_pages_media

  acts_as_list scope: :collected_page
end
