class AddFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :username, :string
    add_column :users, :name, :string
    add_column :users, :active, :boolean
    add_column :users, :api_key, :string
    add_column :users, :tag_line, :string
    add_column :users, :bio, :text
  end
end
