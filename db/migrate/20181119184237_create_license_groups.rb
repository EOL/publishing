class CreateLicenseGroups < ActiveRecord::Migration
  def change
    create_table :license_groups do |t|
      t.string :label_key
      t.string :desc_key
    end
  end
end
