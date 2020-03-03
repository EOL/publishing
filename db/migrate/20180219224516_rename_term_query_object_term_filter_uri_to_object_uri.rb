class RenameTermQueryObjectTermFilterUriToObjectUri < ActiveRecord::Migration[4.2]
  def change
    rename_column :term_query_object_term_filters, :uri, :obj_uri
  end
end
