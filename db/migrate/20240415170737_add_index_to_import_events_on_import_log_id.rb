class AddIndexToImportEventsOnImportLogId < ActiveRecord::Migration[5.2]
  def change
    add_index :import_events, :import_log_id
  end
end
