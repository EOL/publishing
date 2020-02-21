class ContentResourcePkCanBeNull < ActiveRecord::Migration[4.2]
  def up
    change_column :media, :resource_pk, :string, null: true, comment: "was: identifier"
    change_column :articles, :resource_pk, :string, null: true, comment: "was: identifier"
    change_column :links, :resource_pk, :string, null: true, comment: "was: identifier"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
