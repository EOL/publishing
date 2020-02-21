class AddIdToReferences < ActiveRecord::Migration[4.2]
  def change
    add_column :references, :id, :int, null: false, unique: true, auto_increment: true
  end
end
