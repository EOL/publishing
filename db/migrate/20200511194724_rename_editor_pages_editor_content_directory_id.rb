class RenameEditorPagesEditorContentDirectoryId < ActiveRecord::Migration[5.2]
  def change
    add_column :editor_pages, :editor_page_directory_id, :integer
  end
end
