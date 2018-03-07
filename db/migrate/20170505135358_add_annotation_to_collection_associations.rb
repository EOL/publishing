class AddAnnotationToCollectionAssociations < ActiveRecord::Migration
  def change
    add_column :collection_associations, :annotation, :text
  end
end
