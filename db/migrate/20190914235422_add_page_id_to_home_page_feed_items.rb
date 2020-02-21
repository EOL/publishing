class AddPageIdToHomePageFeedItems < ActiveRecord::Migration[4.2]
  def change
    add_column :home_page_feed_items, :page_id, :integer
  end
end
