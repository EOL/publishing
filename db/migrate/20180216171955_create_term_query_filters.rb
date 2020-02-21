class CreateTermQueryFilters < ActiveRecord::Migration[4.2]
  def change
    create_table :term_query_filters do |t|
      t.integer :term_query_id
      t.string :pred_uri
      t.integer :object_id
      t.string :object_type
      t.timestamps null: false
    end
    add_index :term_query_filters, :term_query_id
    add_index :term_query_filters, [:object_type, :object_id]
  end
end
