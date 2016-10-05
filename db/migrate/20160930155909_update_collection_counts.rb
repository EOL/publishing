class UpdateCollectionCounts < ActiveRecord::Migration
  def change
    remove_column :collections, :collection_items_count
    add_column :collections, :collected_pages_count, :integer, default: 0
    add_column :collections, :collection_associations_count, :integer, default: 0
  end
end
