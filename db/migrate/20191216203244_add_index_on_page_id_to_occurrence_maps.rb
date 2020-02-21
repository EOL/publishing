class AddIndexOnPageIdToOccurrenceMaps < ActiveRecord::Migration[4.2]
  def change
    add_index :occurrence_maps, :page_id
  end
end
