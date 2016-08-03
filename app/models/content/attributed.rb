# Content with a little more
class Content::Attributed
  extend ActiveSupport::Concern

  included do
    belongs_to :license
    belongs_to :location
    belongs_to :sytlesheet
    belongs_to :javascript
    belongs_to :bibliographic_citation

    has_many :collection_items, as: :item
    has_many :collection_item_exemplars, as: :exemplar
    has_many :collections, through: :collection_items
  end
end
