class AddStatusToGbifDownloads < ActiveRecord::Migration[5.2]
  def change
    add_column :gbif_downloads, :status, :integer
  end
end
