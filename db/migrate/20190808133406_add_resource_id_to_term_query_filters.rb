class AddResourceIdToTermQueryFilters < ActiveRecord::Migration[4.2]
  def change
    add_column :term_query_filters, :resource_id, :integer
  end
end
