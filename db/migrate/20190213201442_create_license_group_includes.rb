class CreateLicenseGroupIncludes < ActiveRecord::Migration
  def change
    create_table :license_group_includes do |t|
      t.integer :this_id
      t.integer :includes_id
      t.index(:this_id)
      t.index(:includes_id)
      t.index([:this_id, :includes_id], unique: true)
    end

  end
end
