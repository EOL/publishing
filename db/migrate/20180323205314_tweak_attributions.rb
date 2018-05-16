class TweakAttributions < ActiveRecord::Migration
  def change
    change_column :attributions, :content_id, :integer, null: true
    add_column :attributions, :content_resource_fk, :string, null: false
  end
end
