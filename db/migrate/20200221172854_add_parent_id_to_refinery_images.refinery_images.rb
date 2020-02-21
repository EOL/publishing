# This migration comes from refinery_images (originally 20180711122352)
class AddParentIdToRefineryImages < ActiveRecord::Migration[4.2][5.1]
  def change
    add_column :refinery_images, :parent_id, :integer
  end
end