class AddAnnotationToCollectedPages < ActiveRecord::Migration[4.2]
  def change
    add_column :collected_pages, :annotation, :text
  end
end
