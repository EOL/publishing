class AddTypeToCollections < ActiveRecord::Migration
  def change
    add_column :collections, :collection_type, :integer, default: 0
  end
end
