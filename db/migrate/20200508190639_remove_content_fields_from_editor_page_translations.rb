class RemoveContentFieldsFromEditorPageTranslations < ActiveRecord::Migration[5.2]
  def change
    remove_column :editor_page_translations, :title
    remove_column :editor_page_translations, :content
  end
end
