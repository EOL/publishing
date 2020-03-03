class DropTermQueryFilters < ActiveRecord::Migration[4.2]
  def change
    drop_table :term_query_filters
  end
end
