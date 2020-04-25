class AddDigestToTermQueries < ActiveRecord::Migration[5.2]
  def change
    add_column :term_queries, :digest, :string
    add_index :term_queries, :digest
  end
end
