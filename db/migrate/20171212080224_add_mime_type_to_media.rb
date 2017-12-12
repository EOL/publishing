class AddMimeTypeToMedia < ActiveRecord::Migration
  def change
    add_column :media, :mime_type, :integer
  end
end
