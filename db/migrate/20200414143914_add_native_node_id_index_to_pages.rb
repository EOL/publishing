class AddNativeNodeIdIndexToPages < ActiveRecord::Migration[5.2]
  def change
    add_index :pages, :native_node_id
  end
end
