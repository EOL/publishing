class CreateLicencesLicenceGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :license_groups_licenses do |t|
      t.belongs_to :license, index: true
      t.belongs_to :license_group, index: true
    end
  end
end
