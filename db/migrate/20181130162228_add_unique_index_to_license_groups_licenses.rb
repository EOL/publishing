class AddUniqueIndexToLicenseGroupsLicenses < ActiveRecord::Migration
  def change
    add_index :license_groups_licenses, [:license_id, :license_group_id], unique: true
  end
end
