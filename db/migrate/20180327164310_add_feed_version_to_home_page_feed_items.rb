class AddFeedVersionToHomePageFeedItems < ActiveRecord::Migration[4.2]
  def change
    change_table :home_page_feed_items do |t|
      t.integer :feed_version, :index => true
      t.index :feed_version
    end
  end
end
