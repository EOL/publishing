class AddNodesAncestorsHarvDbIdIndex < ActiveRecord::Migration[4.2]
  def change
    add_index :nodes, :harv_db_id
  end
end
