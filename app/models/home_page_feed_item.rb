class HomePageFeedItem < ApplicationRecord
  belongs_to :home_page_feed, :inverse_of => :items
  belongs_to :page, optional: true
  validates_presence_of :home_page_feed
  validates_presence_of :feed_version

  after_initialize :init_feed_version

  def fields
    home_page_feed.fields
  end

  private
  def init_feed_version
    self.feed_version ||= home_page_feed.draft_version if home_page_feed
  end
end
