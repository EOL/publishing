class CreateLicencesLicenceGroups < ActiveRecord::Migration
  def change
    create_table :license_groups_licenses do |t|
      t.belongs_to :license, index: true
      t.belongs_to :license_group, index: true
    end
  end
end
