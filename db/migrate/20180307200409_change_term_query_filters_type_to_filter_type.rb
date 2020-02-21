class ChangeTermQueryFiltersTypeToFilterType < ActiveRecord::Migration[4.2]
  def change
    rename_column :term_query_filters, :type, :filter_type
  end
end
