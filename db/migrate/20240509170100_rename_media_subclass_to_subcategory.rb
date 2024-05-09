class AddIndexToImportEventsOnImportLogId < ActiveRecord::Migration[5.2]
  def change
    rename_column :media, :subclass, :subcategory
  end
end
