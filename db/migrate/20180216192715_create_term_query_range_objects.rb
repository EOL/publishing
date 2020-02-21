class CreateTermQueryRangeObjects < ActiveRecord::Migration[4.2]
  def change
    create_table :term_query_range_objects do |t|
      t.float :from_value
      t.float :to_value
      t.string :units_uri

      t.timestamps null: false
    end
  end
end
