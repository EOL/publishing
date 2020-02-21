class AddStatusToUserDownloads < ActiveRecord::Migration[4.2]
  def change
    add_column :user_downloads, :status, :integer, default: 0
  end
end
