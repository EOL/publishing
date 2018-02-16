class RemovePairsFromTermQueries < ActiveRecord::Migration
  def change
    remove_column :term_queries, :pairs
  end
end
