class RenameTermQueryObjectTermObjects < ActiveRecord::Migration
  def change
    rename_table :term_query_object_term_objects, :term_query_object_term_filters
  end
end
