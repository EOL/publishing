class AddSearchUrlToUserDownload < ActiveRecord::Migration[4.2][4.2]
  def change
    add_column :user_downloads, :search_url, :text
  end
end
