class AddProcessingSinceToUserDownloads < ActiveRecord::Migration
  def change
    add_column :user_downloads, :processing_since, :datetime
  end
end
