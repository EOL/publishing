class DropTermQueryFilters < ActiveRecord::Migration
  def change
    drop_table :term_query_filters
  end
end
