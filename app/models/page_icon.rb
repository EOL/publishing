class PageIcon < ActiveRecord::Base
  belongs_to :page, inverse_of: :page_icons
  belongs_to :medium, inverse_of: :page_icons
  belongs_to :user, inverse_of: :page_icons

  scope :most_recent, -> { order(created_at: :desc).limit(1) }

  after_create :bump_icon

  def self.fix
    Page.where(["updated_at > ?", 1.day.ago]).find_each do |page|
      icon = if page.page_icons.any?
        page.page_icons.last.medium
      elsif page.media.where(subclass: Medium.subclasses[:image]).any?
        page.media.where(subclass: Medium.subclasses[:image]).first
      elsif page.media.any?
        page.media.first
      else
        nil
      end
      page.update_attribute(:medium_id, icon.id) if icon
    end
  end

  def page_content
    @page_content ||= PageContent.where(page_id: page_id, content_type: Medium,
      content_id: medium_id).first
  end

  def bump_icon
    page_content.move_to_top if page_content
    page.update_attribute(:medium_id, medium_id) if page
  end
end
