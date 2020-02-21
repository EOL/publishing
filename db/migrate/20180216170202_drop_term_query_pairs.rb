class DropTermQueryPairs < ActiveRecord::Migration[4.2]
  def change
    drop_table :term_query_pairs
  end
end
