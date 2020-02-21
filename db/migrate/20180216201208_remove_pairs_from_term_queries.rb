class RemovePairsFromTermQueries < ActiveRecord::Migration[4.2]
  def change
    remove_column :term_queries, :pairs
  end
end
