class CreateHomePageFeedItems < ActiveRecord::Migration[4.2]
  def change
    create_table :home_page_feed_items do |t|
      t.string :img_url
      t.string :link_url
      t.string :label
      t.text :desc
      t.integer :home_page_feed_id, :index => true

      t.timestamps null: false
    end
  end
end
