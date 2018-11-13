class AddPageIdAndPositionIndexToPageContents < ActiveRecord::Migration
  def change
    add_index :page_contents, [:page_id, :position], name: 'page_id_by_position'
  end
end
