class PageIcon < ActiveRecord::Base
  belongs_to :page, inverse_of: :page_icons
  belongs_to :medium, inverse_of: :page_icons
  belongs_to :user, inverse_of: :page_icons

  scope :most_recent, -> { order(created_at: :desc).limit(1) }

  after_create :bump_icon

  def page_content
    PageContent.where(page_id: page_id, content_type: Medium,
      content_id: medium_id).first
  end

  def bump_icon
    page_content.move_to_top
  end
end
