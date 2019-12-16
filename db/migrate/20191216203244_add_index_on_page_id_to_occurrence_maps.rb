class AddIndexOnPageIdToOccurrenceMaps < ActiveRecord::Migration
  def change
    add_index :occurrence_maps, :page_id
  end
end
