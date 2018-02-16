class AddTermQueryIdToFilters < ActiveRecord::Migration
  def change
    add_column :term_query_numeric_filters, :term_query_id, :integer
    add_column :term_query_range_filters, :term_query_id, :integer
    add_column :term_query_object_term_filters, :term_query_id, :integer
  end
end
