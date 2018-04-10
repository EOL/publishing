class CreateHomePageFeeds < ActiveRecord::Migration
  def change
    create_table :home_page_feeds do |t|
      t.string :name
      t.integer :fields

      t.timestamps null: false
    end
  end
end
