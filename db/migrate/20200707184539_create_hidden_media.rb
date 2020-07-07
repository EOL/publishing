class CreateHiddenMedia < ActiveRecord::Migration[5.2]
  def change
    create_table :hidden_media do |t|
      t.string :resource_pk
      t.integer :resource_id
      t.integer :medium_id
      t.index :medium_id

      t.timestamps
    end
  end
end
