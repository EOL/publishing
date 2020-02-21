class RenameTermQueryFiltersNumOpToOp < ActiveRecord::Migration[4.2]
  def change
    rename_column :term_query_filters, :num_op, :op
  end
end
