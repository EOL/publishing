class ChangeLicenseGroupsToSingleKey < ActiveRecord::Migration
  def change
    change_table :license_groups do |t|
      t.remove :label_key
      t.remove :desc_key
      t.string :key
    end
  end
end
