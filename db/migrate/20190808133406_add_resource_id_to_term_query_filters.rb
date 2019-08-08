class AddResourceIdToTermQueryFilters < ActiveRecord::Migration
  def change
    add_column :term_query_filters, :resource_id, :integer
  end
end
