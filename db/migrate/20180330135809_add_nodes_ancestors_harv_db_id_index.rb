class AddNodesAncestorsHarvDbIdIndex < ActiveRecord::Migration
  def change
    add_index :nodes, :harv_db_id
  end
end
