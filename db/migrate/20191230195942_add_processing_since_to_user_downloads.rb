class AddProcessingSinceToUserDownloads < ActiveRecord::Migration[4.2]
  def change
    add_column :user_downloads, :processing_since, :datetime
  end
end
