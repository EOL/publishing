class TermNode # Just 'Term' conflicts with a class in some gem. *sigh*
  include Neo4j::ActiveNode
  property :name
  property :definition
  property :comment
  property :attribution
  property :is_hidden_from_overview
  property :is_hidden_from_glossary
  property :position
  property :type
  id_property :uri

  self.mapped_label_name = 'Term'

  @text_search_fields = %w[name]
  searchkick word_start: @text_search_fields, text_start: @text_search_fields

  def self.search_import
    self.all(:t).where(
      "t.is_hidden_from_overview = false "\
      " AND ("\
      "(t)<-[:object_term]-(:Trait)"\
      " OR "\
      "(t)<-[:predicate]-(:Trait)"\
      ")"
    )
  end

  def search_data
    {
      name: name
    }
  end
end
