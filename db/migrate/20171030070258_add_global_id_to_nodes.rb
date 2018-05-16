class AddGlobalIdToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :global_node_id, :integer, index: true
  end
end
