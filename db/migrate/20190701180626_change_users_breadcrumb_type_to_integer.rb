class ChangeUsersBreadcrumbTypeToInteger < ActiveRecord::Migration[4.2]
  def up
    remove_column :users, :breadcrumb_type
    add_column :users, :breadcrumb_type, :integer
  end

  def down
    remove_column :users, :breadcrumb_type
    add_column :users, :breadcrumb_type, :string
  end
end
