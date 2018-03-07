class AddHarvPkToHarvestDbTables < ActiveRecord::Migration
  def change
    %w[referent node identifier scientific_name node_ancestor vernacular article medium image_info].each do |type|
      table = type.pluralize
      add_column table, :harv_db_id, :integer, comment: "ID from harvest DB. Null allowed; this is only for reference."
    end
  end
end
