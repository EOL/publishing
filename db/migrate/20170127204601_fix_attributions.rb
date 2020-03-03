class FixAttributions < ActiveRecord::Migration[4.2]
  def up
    remove_column :attributions, :attribution_id
    add_column :attributions, :resource_id, :integer, null: false
    add_column :attributions, :resource_pk, :string, index: true
  end

  def down
    add_column :attributions, :attribution_id, :integer, null: false, index: true
    remove_column :attributions, :resource_id
    remove_column :attributions, :resource_pk
  end
end
