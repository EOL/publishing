class RemoveDraftIdPublishedIdFromEditorPageTranslations < ActiveRecord::Migration[5.2]
  def change
    remove_column :editor_page_translations, :draft_id
    remove_column :editor_page_translations, :published_id
  end
end
