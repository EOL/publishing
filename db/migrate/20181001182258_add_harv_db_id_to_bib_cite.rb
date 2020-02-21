class AddHarvDbIdToBibCite < ActiveRecord::Migration[4.2]
  def change
    add_column :bibliographic_citations, :harv_db_id, :integer, comment: "ID from harvest DB. Null allowed; this is only for reference."
    add_index :bibliographic_citations, :harv_db_id
  end
end
