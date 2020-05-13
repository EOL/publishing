class IndexEditorPageDirectoriesOnName < ActiveRecord::Migration[5.2]
  def change
    add_index :editor_page_directories, :name
  end
end
