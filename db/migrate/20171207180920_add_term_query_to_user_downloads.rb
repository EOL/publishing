class AddTermQueryToUserDownloads < ActiveRecord::Migration
  def change
    add_column :user_downloads, :term_query_id, :integer, index: true
    add_index :user_downloads, :term_query_id
  end
end
