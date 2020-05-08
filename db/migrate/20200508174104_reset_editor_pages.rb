class ResetEditorPages < ActiveRecord::Migration[5.2]
  def change
    change_table :editor_pages do |t|
      t.remove :title
      t.remove :content
      t.string :name
    end
  end
end
