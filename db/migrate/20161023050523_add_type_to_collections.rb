class AddTypeToCollections < ActiveRecord::Migration[4.2]
  def change
    add_column :collections, :collection_type, :integer, default: 0
  end
end
