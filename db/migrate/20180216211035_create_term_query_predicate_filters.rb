class CreateTermQueryPredicateFilters < ActiveRecord::Migration
  def change
    create_table :term_query_predicate_filters do |t|
      t.integer :term_query_id, :index => true
      t.string  :pred_uri
      t.timestamps null: false
    end
  end
end
