class AddAnnotationToCollectedPages < ActiveRecord::Migration
  def change
    add_column :collected_pages, :annotation, :text
  end
end
