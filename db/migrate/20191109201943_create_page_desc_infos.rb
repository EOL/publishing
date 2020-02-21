class CreatePageDescInfos < ActiveRecord::Migration[4.2]
  def change
    create_table :page_desc_infos do |t|
      t.integer :page_id
      t.integer :species_count
      t.integer :genus_count
      t.integer :family_count

      t.timestamps null: false
    end
  end
end
