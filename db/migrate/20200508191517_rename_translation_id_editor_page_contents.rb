class RenameTranslationIdEditorPageContents < ActiveRecord::Migration[5.2]
  def change
    rename_column :editor_page_contents, :translation_id, :editor_page_translation_id
  end
end
