class AddRoleToUsers < ActiveRecord::Migration[4.2]

  def up
    add_column :users, :role, :integer, null: false, default: User.roles[:user]

    puts User.roles[:admin]
    User.connection.execute("UPDATE users SET role = #{User.roles[:admin]} WHERE admin = true")

    # consider deleting the 'admin' and 'user' columns
    remove_column :users, :admin
  end

  def down
    # reinstate 'admin' if it was deleted above
    add_column :users, :admin, :boolean, null: false, default: false

    User.connection.execute("UPDATE users SET admin = true WHERE role = #{User.roles[:admin]}")

    remove_column :users, :role
  end
end
