class CreateEditorPageDirectories < ActiveRecord::Migration[5.2]
  def change
    create_table :editor_page_directories do |t|
      t.string :name

      t.timestamps
    end
  end
end
