class AddPageIdToHomePageFeedItems < ActiveRecord::Migration
  def change
    add_column :home_page_feed_items, :page_id, :integer
  end
end
