class RenameTermQueryObjectTermFilterUriToObjectUri < ActiveRecord::Migration
  def change
    rename_column :term_query_object_term_filters, :uri, :obj_uri
  end
end
