class AddBreadcrumbTypeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :breadcrumb_type, :string
  end
end
