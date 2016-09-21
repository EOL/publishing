class PageIcon < ActiveRecord::Base
  belongs_to :page, inverse_of: :page_icons
  belongs_to :medium, inverse_of: :page_icons
  belongs_to :user, inverse_of: :page_icons

  scope :_last, -> { order(:id).limit(1) }
end
