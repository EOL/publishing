class AddAnnotationToCollectionAssociations < ActiveRecord::Migration[4.2]
  def change
    add_column :collection_associations, :annotation, :text
  end
end
