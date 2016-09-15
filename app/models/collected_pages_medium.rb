class CollectedPagesMedium < ActiveRecord::Base
  belongs_to :collected_page
  belongs_to :medium

  acts_as_list scope: :collected_page
end
