class AddDuplicationToUserDownloads < ActiveRecord::Migration[5.2]
  def change
    add_column :user_downloads, :duplication, :integer
  end
end
