class AddSlugToEditorContents < ActiveRecord::Migration[5.2]
  def change
    remove_index :editor_pages, :slug
    add_index :editor_pages, :slug, unique: true
  end
end
