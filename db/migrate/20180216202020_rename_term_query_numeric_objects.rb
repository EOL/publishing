class RenameTermQueryNumericObjects < ActiveRecord::Migration[4.2]
  def change
    rename_table :term_query_numeric_objects, :term_query_numeric_filters
  end
end
