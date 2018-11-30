class PageIcon < ActiveRecord::Base
  belongs_to :page, inverse_of: :page_icons
  belongs_to :medium, inverse_of: :page_icons
  belongs_to :user, inverse_of: :page_icons

  scope :most_recent, -> { order(created_at: :desc).limit(1) }

  after_create :bump_icon

  class << self
    def fix
      Page.where(["updated_at > ?", 1.day.ago]).find_each do |page|
        icon =  if page.page_icons.any?
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

    def fix_all
      Page.includes(:page_icons).find_each do |page|
        fix_all_at_position(0)
        # fix_all_at_position(1) # TODO: reenable this before you run it again.
      end
    end

    def fix_all_at_position(pos)
      if PageContent.where(page_id: page.id, position: pos).limit(2).count > 1
        PageContent.acts_as_list_no_update do
          index = 0
          PageContent.where(page_id: page.id, position: pos).find_each do |content|
            index += 1
            content.update_column :position, index
          end
        end
        page.page_icons.each do |icon|
          icon.bump_icon
        end
      end
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
