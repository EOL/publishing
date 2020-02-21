class CreateTermQueryFilters2 < ActiveRecord::Migration[4.2]
  def change
    create_table :term_query_filters do |t|
      t.integer :term_query_id, :index => true
      t.integer :type
      t.string :pred_uri
      t.string :obj_uri
      t.string :units_uri
      t.float :num_val1
      t.float :num_val2
      t.integer :num_op
    end
  end
end
