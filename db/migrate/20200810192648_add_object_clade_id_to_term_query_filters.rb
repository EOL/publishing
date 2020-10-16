class AddObjectCladeIdToTermQueryFilters < ActiveRecord::Migration[5.2]
  def change
    add_column :term_query_filters, :obj_clade_id, :integer
  end
end
