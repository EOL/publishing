class CreateEditorPageContents < ActiveRecord::Migration[5.2]
  def change
    create_table :editor_page_contents do |t|
      t.string :title
      t.text :content
      t.integer :status
      t.integer :translation_id
      t.index :translation_id

      t.timestamps
    end
  end
end
