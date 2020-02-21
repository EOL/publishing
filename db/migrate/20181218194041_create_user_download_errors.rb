class CreateUserDownloadErrors < ActiveRecord::Migration[4.2]
  def change
    create_table :user_download_errors do |t|
      t.string :message
      t.text :backtrace
      t.integer :user_download_id
      t.index :user_download_id
      t.timestamps null: false
    end
  end
end
