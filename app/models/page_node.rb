class PageNode
  include ActiveGraph::Node

  id_property :page_id
  property :descendant_count, default: 0
  property :obj_trait_count, default: 0

  self.mapped_label_name = 'Page'

  has_many :out, :traits, type: :trait, model_class: :TraitNode

  def grouped_traits(limit_per_group = 5)
    as(:page)
      .traits
      .as(:trait)
      .predicate
      .query_as(:predicate)
      .match('(predicate)-[:parent_term|:synonym_of*0..]->(group_predicate:Term)')
      .optional_match(TraitBank::EXEMPLAR_MATCH)
      .with(:page, :trait, :group_predicate, :exemplar_value)
      .order('group_predicate.uri', TraitBank::EXEMPLAR_ORDER)
      .with('group_predicate', "collect(DISTINCT trait)[0..#{limit_per_group}] AS traits")
      .return(:group_predicate, :traits)
      .order('group_predicate.name') # TODO: order on current lang name
  end
end
