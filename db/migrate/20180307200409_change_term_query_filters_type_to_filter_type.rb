class ChangeTermQueryFiltersTypeToFilterType < ActiveRecord::Migration
  def change
    rename_column :term_query_filters, :type, :filter_type
  end
end
