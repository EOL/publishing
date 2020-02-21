class CreateTermQueryPairs < ActiveRecord::Migration[4.2]
  def change
    create_table :term_query_pairs do |t|
      t.string :predicate
      t.string :object
      t.integer :term_query_id, index: true

      t.timestamps null: false
    end
  end
end
