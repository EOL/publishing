class AddKeyIndexToLicenseGroups < ActiveRecord::Migration[4.2]
  def change
    add_index :license_groups, :key
  end
end
