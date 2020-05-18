class AddResponseCodeToGbifDownloads < ActiveRecord::Migration[5.2]
  def change
    add_column :gbif_downloads, :response_code, :integer
  end
end
