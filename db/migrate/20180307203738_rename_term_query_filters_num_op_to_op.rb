class RenameTermQueryFiltersNumOpToOp < ActiveRecord::Migration
  def change
    rename_column :term_query_filters, :num_op, :op
  end
end
