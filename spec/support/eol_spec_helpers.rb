module EolSpecHelpers
  def another_language
    Language.where(group: "de").first_or_create do |l|
      l.code = "deu"; l.group = "de"
    end
  end

  def extinct_data
    fake_fact(Eol::Uris.extinction, Eol::Uris.extinct)
  end

  def marine_data
    fake_fact(Eol::Uris.environment, Eol::Uris.marine)
  end

  def dd_iucn_data(resource)
    fake_fact(Eol::Uris::Iucn.status, Eol::Uris::Iucn.dd, resource_id: iucn.id)
  end

  def fake_data_shell
    {
      resource_pk: "xyz", scientific_name: "hij", metadata: [], resource_id: 1,
      id: "abx"
    }
  end

  def fake_img_path(base_url, w, h = nil)
    orig = Rails.configuration.x.image_path['original']
    ext = Rails.configuration.x.image_path['ext']
    join = Rails.configuration.x.image_path['join']
    by = Rails.configuration.x.image_path['by']
    if w == :orig
      base_url + "#{orig}#{ext}"
    else
      "#{base_url}#{join}#{w}#{by}#{h}#{ext}"
    end
  end

  def fake_fact(predicate_uri, value_uri, options = {})
    data = fake_data_shell.merge(predicate: fake_term(predicate_uri),
      object_term: fake_term(value_uri, options[:name]))
    data[:resource_id] = options[:resource_id] if options[:resource_id]
    data
  end

  def fake_literal_data(predicate_uri, literal)
    fake_data_shell.merge(predicate: fake_term(predicate_uri), literal: literal)
  end

  def fake_term(uri, name = "xyz")
    {
      section_ids: "", name: name, attribution: "", uri: uri,
      is_hidden_from_glossary: false, definition: "abc", comment: "",
      is_hidden_from_overview: false
    }
  end

  def fake_search_results(array)
    results = Searchkick::Results.new(array.first.class, array)
    allow(results).to receive(:empty?) { array.empty? }
    allow(results).to receive(:[]) { |arg| array[arg] }
    allow(results).to receive(:results) { array }
    allow(results).to receive(:results) { array }
    allow(results).to receive(:total_count) { array.count }
    allow(results).to receive(:total_pages) { 1 }
    allow(results).to receive(:current_page) { 1 }
    allow(results).to receive(:limit_value) { 1 }
    allow(results).to receive(:results) { array }
    results
  end

  def fake_pagination(array)
    is_empty = array.empty?
    results = Array(array)
    allow(results).to receive(:total_pages) { 1 }
    allow(results).to receive(:current_page) { 1 }
    allow(results).to receive(:limit_value) { 1 }
    allow(results).to receive(:empty?) { is_empty }
    results
  end

  def double_page(data)
    rank = data[:rank]
    resource = data[:resource]
    media = data[:media] || []
    ancestor = instance_double("Node", ancestors: [], name: "Ancestor Name",
      canonical_form: "Ancestor Canon", page_id: 653421, use_breadcrumb?: true, has_breadcrumb?: true, rank: rank, scientific_name: "Ancestor Sci")
    invisible_ancestor = instance_double("Node", ancestors: [ancestor], name: "InvisibleAncestor Name",
      canonical_form: "InvisibleAncestor Canon", page_id: 653421, use_breadcrumb?: false, has_breadcrumb?: false, rank: rank, scientific_name: "InvisibleAncestor Sci")
    parent = instance_double("Node", ancestors: [ancestor, invisible_ancestor], name: "Parent Name",
      canonical_form: "Parent Canon", page_id: 653421, use_breadcrumb?: true, has_breadcrumb?: true, rank: rank, scientific_name: "Parent Sci")
    node = instance_double("Node", ancestors: [ancestor, invisible_ancestor, parent], name: "SomeTaxon",
      children: [], resource: resource, use_breadcrumb?: true, has_breadcrumb?: true)
    lic2 = instance_double("License", name: "Article license name")
    article = instance_double("Article", name: "Article Name", license: lic2,
      body: "Article body", owner: "Article owner", rights_statement: nil,
      bibliographic_citation: nil, location: nil, attributions: [],
      source_url: nil, resource: resource, resource_pk: "1234")
    sci_name = instance_double("ScientificName", node: node,
      italicized: "<i>Nice scientific</i>",
      taxonomic_status: TaxonomicStatus.synonym)
    vernacular = instance_double("Vernacular", string: "something common",
      language: Language.english, is_preferred?: true, node: node,
      is_preferred_by_resource: true)
    data = [
      { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
        measurement: "657", units: { uri: "http://un.its/one",
        name: "Units URI" }, resource_id: resource.id },
      { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
        object_term: { uri: "http://te.rm/one", name: "Term URI" } },
      { predicate: { uri: "http://predic.ate/two", name: "Uri" },
        literal: "literal data value" } ]
    key_data = {
      { uri: "http://predic.ate/one", name: "Predicate One" } =>
        { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
          measurement: "657", units: { uri: "http://un.its/one",
          name: "Units URI" }, resource_id: resource.id },
      { uri: "http://predic.ate/two", name: "Uri" } =>
        { predicate: { uri: "http://predic.ate/two", name: "Uri" },
          literal: "literal data value" } }
    glossary = {
      "http://predic.ate/one" => { name: "Predicate One" },
      "http://predic.ate/two" => { name: "Predicate Two" },
      "http://un.its/one" => { name: "Units URI" },
      "http://te.rm/one" => { name: "Term URI" }
    }

    instance_double("Page",
      id: 8293,
      ancestors: [ancestor, invisible_ancestor, parent],
      articles: [article],
      articles_count: 1,
      nodes_count: 1,
      glossary: glossary,
      grouped_data: data.group_by { |t| t[:predicate][:uri] },
      habitats: "",
      iucn_status_key: :lc,
      is_it_extinct?: false,
      is_it_marine?: false,
      literature_and_references_count: 3,
      map?: false,
      media_count: media.size,
      nodes: [node],
      name: vernacular.string,
      names_count: 2,
      native_node: node,
      occurrence_map?: false,
      predicates: data.map { |t| t[:predicate][:uri] },
      rank: rank,
      scientific_name: sci_name.italicized,
      scientific_names: [sci_name],
      medium: media.first,
      key_data: key_data,
      data: data,
      data_count: 3,
      vernaculars: [vernacular],
      page_richness: 0,
      page_contents_count: 0,
      links_count: 0,
      maps_count: 0,
      vernaculars_count: 0,
      scientific_names_count: 0,
      referents_count: 0,
      species_count: 0,
      updated_at: Time.now
    )
  end

  def double_empty_page(data)
    rank = data[:rank]
    resource = data[:resource]
    node = instance_double("Node", ancestors: [], name: "SomeTaxon", id: 1,
      children: [], resource: resource, use_breadcrumb?: true, has_breadcrumb?: true)
    sci_name = instance_double("ScientificName", node: node,
      italicized: "<i>Nice scientific</i>",
      taxonomic_status: TaxonomicStatus.synonym)
    instance_double("Page",
      id: 3497,
      articles: [],
      articles_count: 0,
      nodes_count: 0, # NOTE: this should actually be impossible, but JUST IN CASE...
      descendant_species: 0,
      glossary: [],
      grouped_data: nil,
      habitats: "",
      iucn_status_key: nil,
      is_it_extinct?: false,
      is_it_marine?: false,
      literature_and_references_count: 0,
      map?: false,
      media_count: 0,
      nodes: [node],
      name: sci_name.italicized,
      names_count: 0,
      native_node: nil,
      occurrence_map?: false,
      predicates: [],
      rank: rank,
      scientific_name: sci_name.italicized,
      scientific_names: [sci_name],
      medium: nil,
      data: [],
      data_count: 0,
      vernaculars: [],
      page_richness: 0,
      page_contents_count: 0,
      links_count: 0,
      maps_count: 0,
      vernaculars_count: 0,
      scientific_names_count: 0,
      referents_count: 0,
      species_count: 0,
      updated_at: Time.now
    )
  end
end
