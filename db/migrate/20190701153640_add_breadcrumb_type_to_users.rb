class AddBreadcrumbTypeToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :breadcrumb_type, :string
  end
end
