class AddKeyIndexToLicenseGroups < ActiveRecord::Migration
  def change
    add_index :license_groups, :key
  end
end
