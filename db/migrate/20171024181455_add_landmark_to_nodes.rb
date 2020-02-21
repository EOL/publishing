class AddLandmarkToNodes < ActiveRecord::Migration[4.2]
  def change
    add_column :nodes, :landmark, :integer, default: 0
  end
end
