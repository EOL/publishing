class AddTermQueryToUserDownloads < ActiveRecord::Migration
  def change
    add_reference :user_downloads, :term_query, index: true, foreign_key: true
  end
end
