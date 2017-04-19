module EolSpecHelpers
  def another_language
    Language.where(group: "de").first_or_create do |l|
      l.code = "deu"; l.group = "de"
    end
  end

  def extinct_trait
    fake_fact(Eol::Uris.extinction, Eol::Uris.extinct)
  end

  def marine_trait
    fake_fact(Eol::Uris.environment, Eol::Uris.marine)
  end

  def dd_iucn_trait(resource)
    fake_fact(Eol::Uris::Iucn.status, Eol::Uris::Iucn.dd, resource_id: iucn.id)
  end

  def fake_trait_shell
    {
      resource_pk: "xyz", scientific_name: "hij", metadata: [], resource_id: 1,
      id: "abx"
    }
  end

  def fake_fact(predicate_uri, value_uri, options = {})
    trait = fake_trait_shell.merge(predicate: fake_term(predicate_uri),
      object_term: fake_term(value_uri, options[:name]))
    trait[:resource_id] = options[:resource_id] if options[:resource_id]
    trait
  end

  def fake_literal_trait(predicate_uri, literal)
    fake_trait_shell.merge(predicate: fake_term(predicate_uri), literal: literal)
  end

  def fake_term(uri, name = "xyz")
    {
      section_ids: "", name: name, attribution: "", uri: uri,
      is_hidden_from_glossary: false, definition: "abc", comment: "",
      is_hidden_from_overview: false
    }
  end

  def fake_search_results(array)
    results = Array(array)
    allow(results).to receive(:total_pages) { 1 }
    allow(results).to receive(:current_page) { 1 }
    allow(results).to receive(:limit_value) { 1 }
    double("Sunspot::Search", results: results, total: 1)
  end
end
