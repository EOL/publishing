class HomePageFeedItem < ActiveRecord::Base
  belongs_to :home_page_feed, :inverse_of => :items
  validates_presence_of :home_page_feed
  validate :validate_feed_fields

  def fields
    home_page_feed.fields
  end

  private
  def validate_feed_fields
    home_page_feed.fields.each do |field|
      if self.attributes[field.to_s].blank?
        errors.add(field, "can't be blank")
      end
    end
  end
end
