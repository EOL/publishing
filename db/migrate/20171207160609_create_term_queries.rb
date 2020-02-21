class CreateTermQueries < ActiveRecord::Migration[4.2]
  def change
    create_table :term_queries do |t|
      t.string :pairs
      t.integer :clade

      t.timestamps null: false
    end
  end
end
