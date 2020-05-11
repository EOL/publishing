class RenameEditorPagesEditorContentDirectoryId < ActiveRecord::Migration[5.2]
  def change
    rename_column :editor_pages, :editor_content_directory_id, :editor_page_directory_id
  end
end
