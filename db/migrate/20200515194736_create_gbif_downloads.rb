class CreateGbifDownloads < ActiveRecord::Migration[5.2]
  def change
    create_table :gbif_downloads do |t|
      t.integer :user_id
      t.integer :term_query_id
      t.string :status_url
      t.string :result_url

      t.timestamps
    end
  end
end
