class DropEditorContentDirectories < ActiveRecord::Migration[5.2]
  def change
    drop_table :editor_content_directories
  end
end
