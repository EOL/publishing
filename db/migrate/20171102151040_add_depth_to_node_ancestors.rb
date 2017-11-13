class AddDepthToNodeAncestors < ActiveRecord::Migration
  def change
    add_column :node_ancestors, :depth, :integer
  end
end
