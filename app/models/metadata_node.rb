class MetadataNode
  include ActiveGraph::Node

  self.mapped_label_name = 'MetaData'

  id_property :eol_pk
  property :literal

  has_one :in, :trait, type: :metadata, model_class: :TraitNode
  has_one :out, :predicate, type: :predicate, model_class: :TermNode
  has_one :out, :object_term, type: :object_term, model_class: :TermNode
  has_one :out, :units_term, type: :units_term, model_class: :TermNode
  has_one :out, :lifestage_term, type: :lifestage_term, model_class: :TermNode
  has_one :out, :statistical_method_term, type: :statistical_method_term, model_class: :TermNode
  has_one :out, :sex_term, type: :sex_term, model_class: :TermNode
