class CollectionAssociation < ActiveRecord::Base
  belongs_to :collection, inverse_of: :collection_items
  belongs_to :associated, class_name: "Collection",
    inverse_of: :collection_associations

  acts_as_list scope: :collection
end
