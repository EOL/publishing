class CreateImportRuns < ActiveRecord::Migration[4.2]
  def change
    create_table :import_runs do |t|
      t.datetime :completed_at
      t.timestamps
    end
  end
end
