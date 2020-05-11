class AddLocaleToEditorPageContents < ActiveRecord::Migration[5.2]
  def change
    add_column :editor_page_contents, :locale, :string
    rename_column :editor_page_contents, :editor_page_translation_id, :editor_page_id
  end
end
