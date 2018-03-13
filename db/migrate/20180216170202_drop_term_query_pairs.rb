class DropTermQueryPairs < ActiveRecord::Migration
  def change
    drop_table :term_query_pairs
  end
end
