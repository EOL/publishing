class CreateDhDataSets < ActiveRecord::Migration[4.2]
  def change
    create_table :dh_data_sets do |t|
      t.string :dataset_id
      t.string :name

      t.timestamps null: false
    end
  end
end
