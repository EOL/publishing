class AddLandmarkToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :landmark, :integer, default: 0
  end
end
