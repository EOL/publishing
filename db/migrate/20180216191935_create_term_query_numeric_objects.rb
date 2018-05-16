class CreateTermQueryNumericObjects < ActiveRecord::Migration
  def change
    create_table :term_query_numeric_objects do |t|
      t.float :value
      t.integer :op
      t.string :units_uri

      t.timestamps null: false
    end
  end
end
