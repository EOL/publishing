class AddTimeStampsToCollections < ActiveRecord::Migration[4.2]
  def change
    # ooops.
    add_column(:collections, :created_at, :datetime)
    add_column(:collections, :updated_at, :datetime)
    add_column(:collection_items, :created_at, :datetime)
    add_column(:collection_items, :updated_at, :datetime)
    add_column(:collection_item_exemplars, :created_at, :datetime)
    add_column(:collection_item_exemplars, :updated_at, :datetime)
    add_column(:collections_users, :created_at, :datetime)
    add_column(:collections_users, :updated_at, :datetime)
  end
end
