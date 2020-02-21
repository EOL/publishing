class CreateLicenseGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :license_groups do |t|
      t.string :label_key
      t.string :desc_key
    end
  end
end
