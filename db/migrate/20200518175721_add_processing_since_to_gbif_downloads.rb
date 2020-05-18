class AddProcessingSinceToGbifDownloads < ActiveRecord::Migration[5.2]
  def change
    add_column :gbif_downloads, :processing_since, :timestamp
  end
end
