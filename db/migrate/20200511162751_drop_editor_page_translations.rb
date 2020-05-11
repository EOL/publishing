class DropEditorPageTranslations < ActiveRecord::Migration[5.2]
  def change
    drop_table :editor_page_translations
  end
end
