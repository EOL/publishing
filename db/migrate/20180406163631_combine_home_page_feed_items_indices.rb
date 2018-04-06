class CombineHomePageFeedItemsIndices < ActiveRecord::Migration
  def change
    remove_index :home_page_feed_items, :name => "index_home_page_feed_items_on_feed_version"
    remove_index :home_page_feed_items, :name => "index_home_page_feed_items_on_home_page_feed_id"
    add_index :home_page_feed_items, [:home_page_feed_id, :feed_version]
  end
end
