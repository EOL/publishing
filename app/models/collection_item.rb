class CollectionItem < ActiveRecord::Base
  belongs_to :collection, inverse_of: :collection_items
  belongs_to :item, polymorphic: true, inverse_of: :collection_items

  has_many :collection_item_exemplars, as: :exemplars, -> { order(position: :asc) }

  acts_as_list scope: :collection
end
