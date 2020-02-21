class RenameTermQueryRangeObjects < ActiveRecord::Migration[4.2]
  def change
    rename_table :term_query_range_objects, :term_query_range_filters
  end
end
