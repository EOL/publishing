class AddClassificationToResource < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :classification, :boolean, default: false, comment: "Whether or not EOL wants to trust the classification for this resource and use it for display"
  end
end
