class PageNode
  include ActiveGraph::Node

  id_property :page_id
  property :descendant_count, default: 0
  property :obj_trait_count, default: 0

  self.mapped_label_name = 'Page'

  has_many :out, :traits, type: :trait, model_class: :TraitNode
end
