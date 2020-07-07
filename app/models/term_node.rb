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

  autocompletes "autocomplete_name"

  @text_search_fields = %w[name]
  searchkick word_start: @text_search_fields, text_start: @text_search_fields, merge_mappings: true, mappings: {
    properties: autocomplete_searchkick_properties
  }

  OBJ_TERM_TYPE = "value"

  class << self
    def search_import
      self.all(:t).where("t.is_hidden_from_overview = false AND NOT (t)-[:synonym_of]->(:Term)")
    end
  end

  def search_data
    {
      name: name
    }.merge(autocomplete_name_fields)
  end

  def autocomplete_name_fields
    I18n.available_locales.collect do |locale|
      [:"autocomplete_name_#{locale}", i18n_name(locale)]
    end.to_h
  end

  def i18n_name(locale)
    TraitBank::Record.i18n_name_for_locale({
      uri: uri,
      name: name
    }, locale)
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

