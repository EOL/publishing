class TermNode # Just 'Term' conflicts with a module in some gem. *sigh*
  include Neo4j::ActiveNode
  include Autocomplete

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
  searchkick word_start: @text_search_fields, text_start: @text_search_fields, merge_mappings: true, mappings: {
    properties: {
      autocomplete_name: {
        type: "completion"
      }
    }
  }
  autocompletes "autocomplete_name"

  OBJ_TERM_TYPE = "value"

  class << self
    def search_import
      self.all(:t).where(
        "t.is_hidden_from_overview = false "\
        " AND ("\
        "(t)<-[:object_term]-(:Trait)"\
        " OR "\
        "(t)<-[:predicate]-(:Trait)"\
        ")"
      )
    end
  end

  def search_data
    {
      name: name,
      autocomplete_name: name # can't have a duplicate field name for completion field
    }
  end

  def predicate?
    !object_term?   
  end

  def object_term?
    type == OBJ_TERM_TYPE
  end

  def known_type?
    predicate? || object_term?
  end
end

