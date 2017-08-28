class CreateUserDownloads < ActiveRecord::Migration
  def change
    create_table :user_downloads do |t|
      t.references :user
      t.integer :count
      t.integer :clade
      t.text :object_terms
      t.text :predicates
      t.string :filename
      t.datetime :completed_at
      t.datetime :expired_at
      t.timestamps
    end
  end
end
