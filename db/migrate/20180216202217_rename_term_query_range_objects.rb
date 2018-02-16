class RenameTermQueryRangeObjects < ActiveRecord::Migration
  def change
    rename_table :term_query_range_objects, :term_query_range_filters
  end
end
