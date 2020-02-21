class AddIndexToMediaOnResourcePk < ActiveRecord::Migration[4.2]
  def change
    add_index :media, :resource_pk
    add_column :media, :usage_statement, :string
    add_column :image_info, :resource_pk, :string
    add_index :image_info, :resource_pk
  end
end
