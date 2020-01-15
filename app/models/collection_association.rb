class CollectionAssociation < ApplicationRecord
  belongs_to :collection, inverse_of: :collection_associations
  belongs_to :associated, class_name: "Collection",
    inverse_of: :collection_associations

  acts_as_list scope: :collection

  counter_culture :collection
end
