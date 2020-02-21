class AddTermQueryToUserDownloads < ActiveRecord::Migration[4.2]
  def change
    add_column :user_downloads, :term_query_id, :integer, index: true
    add_index :user_downloads, :term_query_id
  end
end
