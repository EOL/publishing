class AddRoleToUsers < ActiveRecord::Migration

  # 0 = nobody, 100 = admin.  See enum in models/user.rb
  # There must be a better way to do this

  @@user = 10
  @@admin = 100

  def up
    add_column :users, :role, :integer, null: false, default: @@user
    User.connection.execute("UPDATE users SET role = #{@@admin} WHERE admin = true")

    # consider deleting the 'admin' and 'user' columns
    remove_column :users, :admin
  end

  def down
    # reinstate 'admin' and 'user' if they were deleted above
    add_column :users, :admin, :boolean, null: false, default: false

    User.connection.execute("UPDATE users SET admin = (role = #{@@admin})")
    remove_column :users, :role
  end
end
