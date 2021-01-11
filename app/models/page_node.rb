class PageNode
  include ActiveGraph::Node

  id_property :page_id
  property :descendant_count, default: 0
  property :obj_trait_count, default: 0

  self.mapped_label_name = 'Page'
  # NOTE: There's no activegraph support for multiple types, e.g., :trait|:inferred_trait, so 
  # you have to query manually if you want both types.
  has_many :out, :traits, type: :trait, model_class: :TraitNode
  has_many :out, :inferred_traits, type: :inferred_trait, model_class: :TraitNode
end

