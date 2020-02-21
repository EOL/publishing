class RenameTermQueryObjectTermObjects < ActiveRecord::Migration[4.2]
  def change
    rename_table :term_query_object_term_objects, :term_query_object_term_filters
  end
end
