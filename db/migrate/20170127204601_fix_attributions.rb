class FixAttributions < ActiveRecord::Migration
  def up
    remove_column :attributions, :attribution_id
  end

  def down
    add_column :attributions, :attribution_id, :integer, null: false, index: true
  end
end
