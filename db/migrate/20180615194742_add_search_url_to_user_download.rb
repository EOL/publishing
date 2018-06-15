class AddSearchUrlToUserDownload < ActiveRecord::Migration
  def change
    add_column :user_downloads, :search_url, :text
  end
end
