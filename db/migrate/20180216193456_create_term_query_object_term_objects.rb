class CreateTermQueryObjectTermObjects < ActiveRecord::Migration
  def change
    create_table :term_query_object_term_objects do |t|
      t.string :uri

      t.timestamps null: false
    end
  end
end
