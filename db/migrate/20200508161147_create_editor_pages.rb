class CreateEditorPages < ActiveRecord::Migration[5.2]
  def change
    create_table :editor_pages do |t|
      t.string :title
      t.string :slug
      t.text :content
      t.index :slug

      t.timestamps
    end
  end
end
