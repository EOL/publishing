class CreateCollectionPages < ActiveRecord::Migration
  def change
    # NOTE: we removed medium_id and the name stuff.
    create_table :collected_pages do |t|
      t.integer :collection_id, index: true, null: false
      t.integer :page_id, index: true, null: false
      t.integer :vernacular_id, comment: "NULL means 'use the page name'; a value here is an override"
      t.integer :scientific_name_id, comment: "NULL means 'use the page name'; a value here is an override"
      t.integer :medium_id, comment: "NULL means 'use the page icon'; a value here is an override"
      t.integer :position

      t.timestamps, null: false
    end
    add_index(:collected_pages, [:collection_id, :page_id],
      name: "enforce_unique_pairs", unique: true)

    create_join_table :collected_pages, :media do |t|
      t.index :collected_page_id
      t.integer :position
    end

    # TODO: remove these guys, they are a distraction until we need them.
    create_join_table :collected_pages, :articles do |t|
      t.index :collected_page_id
      t.integer :position
    end

    create_join_table :collected_pages, :links do |t|
      t.index :collected_page_id
      t.integer :position
    end

    drop_table :collection_item_exemplars
  end
end
