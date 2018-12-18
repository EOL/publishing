class AddStatusToUserDownloads < ActiveRecord::Migration
  def change
    add_column :user_downloads, :status, :integer, default: 0
  end
end
