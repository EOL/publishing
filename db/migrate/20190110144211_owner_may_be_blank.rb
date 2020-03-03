class OwnerMayBeBlank < ActiveRecord::Migration[4.2]
  def up
    # NOTE: it's already okay in articles, for some reason.
    change_column :media, :owner, :text, limit: 65535, null: true
  end

  def down
    change_column :media, :owner, :text, limit: 65535, null: false
  end
end
