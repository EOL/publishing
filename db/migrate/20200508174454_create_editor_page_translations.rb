class CreateEditorPageTranslations < ActiveRecord::Migration[5.2]
  def change
    create_table :editor_page_translations do |t|
      t.string :title
      t.text :content
      t.string :locale
      t.integer :draft_id
      t.integer :published_id
      t.integer :editor_page_id

      t.index :editor_page_id

      t.timestamps
    end
  end
end
