class CreateOpenAuthentications < ActiveRecord::Migration[4.2]
  def change
    create_table :open_authentications do |t|
      t.string :provider, null: false
      t.string :uid, null: false
      t.timestamps null: false
    end
     add_reference :open_authentications, :user, index: true
  end
end
