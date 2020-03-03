class CreatePageIcons < ActiveRecord::Migration[4.2]
  def change
    create_table :page_icons do |t|
      t.integer :page_id, index: true
      t.integer :user_id, index: true, comment: "Indexed so we know how many icons a curator has set."
      t.integer :medium_id, index: true, comment: "indexed so we can show 'this image was made an exemplar' on the object page."

      t.timestamps null: false
    end
  end
end
