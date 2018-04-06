class AddPublishedVersionToHomePageFeeds < ActiveRecord::Migration
  def change
    add_column :home_page_feeds, :published_version, :integer, :default => 0
  end
end
