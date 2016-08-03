class CollectionItemExemplar < ActiveRecord::Base
  belongs_to :collection_item, inverse_of: :exemplars
  # Exemplar is always a Content instnace:
  belongs_to :exemplar, polymorphic: true,
    inverse_of: :collection_item_exemplars

  acts_as_list scope: :collection_item
end
