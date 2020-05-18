class GbifDownloadFields < ActiveRecord::Migration[5.2]
  def change
    add_column :gbif_downloads, :completed_at, :timestamp
    add_column :gbif_downloads, :error_response, :text
  end
end
