class AddTimestampsToDataIntegrityChecks < ActiveRecord::Migration[5.2]
  def change
    change_table :data_integrity_checks do |t|
      t.datetime :created_at, null: false, default: DateTime.now
      t.datetime :updated_at, null: false, default: DateTime.now
    end
  end
end
