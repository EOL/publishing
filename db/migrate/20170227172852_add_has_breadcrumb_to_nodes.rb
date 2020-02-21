class AddHasBreadcrumbToNodes < ActiveRecord::Migration[4.2]
  def change
    add_column :nodes, :has_breadcrumb, :boolean, default: true,
      comment: "Mostly used for DWH to 'hide' most nodes and only show the "\
        "important ones. Defaults to true because browsing any OTHER hierarchy "\
        "should default to showing ALL nodes, so harvest of DWH will just have a "\
        "lot of 'false' values: NBD."
  end
end
