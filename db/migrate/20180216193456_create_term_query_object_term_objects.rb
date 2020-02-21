class CreateTermQueryObjectTermObjects < ActiveRecord::Migration[4.2]
  def change
    create_table :term_query_object_term_objects do |t|
      t.string :uri

      t.timestamps null: false
    end
  end
end
