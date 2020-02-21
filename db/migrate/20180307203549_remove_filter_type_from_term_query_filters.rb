class RemoveFilterTypeFromTermQueryFilters < ActiveRecord::Migration[4.2]
  def change
    remove_column :term_query_filters, :filter_type
  end
end
