class Import::Page
  def from_file(name)
    # Test with name = '/Users/jrice/Downloads/store-328598.json'
    file = File.read(name)
    data = JSON.parse(file)
    # NOTE: You mmmmmmight want to delete everything before you call this, but
    # I'm skipping that now. Sometimes you won't want to, anyway...
    page = Page.create(id: data["id"])
    node = build_node(data["native_node"], page)
    build_sci_name(ital: data["native_node"]["scientific_name"],
      canon: data["native_node"]["canonical_form"], node: node, page: page)
    data["vernaculars"].each { |cn| build_vernacular(cn, node, page) }
    last_position = 0
    data["maps"].each do |m|
      build_map(m, node, page, last_position += 1)
    end
    data["articles"].each do |a|
      build_article(a, node, page, last_position += 1)
    end
    data["media"].each do |m|
      build_image(m, node, page, last_position += 1)
    end
    data["collections"].each do |c|
      collection = build_collection(c)
      add_page_to_collection(page, collection)
    end
    data["traits"].each do |t_data|
      # NOTE: these are (currently) super-simple traits with no metadata!
      unless Trait.exists?(t_data["uri"])
        units = create_uri(t_data["units"]) if t_data["units"]
        value = Uri.is_uri?(t_data["value"]) ?
          create_uri(t_data["value"]) :
          t_data["value"]
        end
        Trait.create(page: page, resource: resource, uri: t_data["uri"],
          predicate: create_uri(t_data["predicate"]), value: value, units: units)
      end
    end
    # TODO json_map ...we don't use it, yet, so leaving for later.
    page.save!
  end

  def create_uri(

  # NOTE: collections have no users associated from this scirpt. Doesn't matter
  # for demos.
  def build_collection(c_data)
    if Collection.where(name: c_data["name"]).exists?
      Collection.where(name: c_data["name"]).first
    else
      Collection.create(name: c_data["name"], icon: c_data["icon"],
        description: c_data["description"])
    end
  end

  def add_page_to_collection(page, collection)
    if CollectionItem.where(collection_id: collection.id,
        collected_item_id: page.id, collected_item_type: "Page").exists?
      true # No need to return anything, here. :|
    else
      CollectionItem.create(collection_id: collection.id,
        collected_item_id: page.id, collected_item_type: "Page")
    end
  end

  def build_image(i_data, node, page, position)
    build_content(Medium, i_data, type: "image", format: "jpg", node: node,
      page: page, position: position)
  end

  def build_article(a_data, node, page, position)
    build_content(Article, a_data, node: node, page: page, position: position)
  end

  def build_map(m_data, node, page, position)
    build_content(Map, m_data, node: node, page: page, position: position)
  end

  def build_content(klass, c_data, options = {})
    type = options["type"] || c_data.delete("type")
    ext = options["format"] || c_data.delete("format")
    # NOTE this only allows us to import ONE version of a single GUID, but
    # that's desirable: the website is intended to only contain published
    # versions of data.
    if klass.where(guid: c_data["guid"]).exists?
      klass.where(guid: c_data["guid"]).first
    else
      resource = build_resource(c_data["provider"])
      # Common fields for all content:
      hash = {
        guid: c_data["guid"],
        resource_pk: c_data["resource_pk"],
        provider: resource,
        license: build_license(c_data["license"]),
        language: build_language(c_data["language"]),
        bibliographic_citation: build_citation(c_data["bibliographic_citation"]),
        owner: c_data["owner"],
        name: c_data["name"],
        source_url: c_data["source_url"]
      }
      # Type-specific fields:
      hash[:description] = c_data["description"] if c_data["description"]
      hash[:body] = c_data["body"] if c_data["body"]
      hash[:base_url] = c_data["base_url"] if c_data["base_url"]
      hash[:type] = type if type # Not always needed.
      hash[:format] = ext if ext # Not always needed.
      content = klass.create(hash)
      PageContent.create(
        page: options["page"],
        source_page: options["page"],
        position: options["position"],
        content: content,
        trust: :trusted
      )
      node.ancestors.each do |ancestor|
        # TODO: we will have to figure out a proper algorithm for position. :S
        pos = PageContent.where(page_id: ancestor.page_id).maximum(:position) || 0
        pos += 1
        PageContent.create(
          page_id: ancestor.page_id,
          source_page: options["page"],
          position: pos,
          content: content,
          trust: :trusted
        )
      end
      content
    end
  end

  def build_node(node_data, page, resource = nil)
    resource ||= build_resource(node_data["resource"])
    if Node.where(resource_id: resource.id, resource_pk: node_data["resource_pk"]).exists?
      return Node.where(resource_id: resource.id,
        resource_pk: node_data["resource_pk"]).first
    else
      parent = if node_data["parent"]
        build_node(node_data, page, resource)
      else
        nil
      end

      rank = build_rank(node_data["rank"])
      Node.create(id: node_data["id"],
        resource_id: resource.id,
        page_id: page.id,
        lft: node_data["lft"],
        rgt: node_data["rgt"],
        scientific_name: node_data["scientific_name"], # denormalized
        canonical_form: node_data["canonical_form"],
        resource_pk: node_data["resource_pk"],
        source_url: node_data["source_url"],
        is_hidden: false,
        parent_id: parent ? parent.id : null
      )
    end
  end

  def build_sci_name(opts)
    if ScientificName.where(italicized: opts[:ital]).exists?
      ScientificName.where(italicized: opts[:ital]).first
    else
      ScientificName.create(italicized: opts[:ital], canonical_form: opts[:canon],
        page_id: opts[:page].id, node_id: opts[:node].id, is_preferred: true,
        taxonomic_status_id: TaxonomicStatus.preferred.id)
    end
  end

  def build_vernacular(v_data, node, page)
    lang = build_language(v_data["language"])
    if Vernacular.where(string: v_data["string"], language_id: lang.id, node_id: node.id).exists?
      Vernacular.where(string: v_data["string"], language_id: lang.id, node_id: node.id).first
    else
      Vernacular.create(string: v_data["string"], language_id: lang.id,
        node_id: node.id, page_id: page.id, preferred: v_data["preferred"],
        preferred_by_resource: v_data["preferred"])
    end
  end

  def build_language(code)
    if Language.where(code: code).exists?
      Language.where(code: code).first
    else
      Language.create(code: code, group: code[0..1])
    end
  end

  def build_license(l_data)
    if License.where(source_url: l_data["source_url"]).exists?
      License.where(source_url: l_data["source_url"]).first
    else
      License.create(source_url: l_data["source_url"],
        name: l_data["name"], icon_url: l_data["icon_url"],
        can_be_chosen_by_partners: l_data["can_be_chosen_by_partners"])
    end
  end

  def build_resource(res_data)
    name = res_data["name"]
    if Resource.where(name: name).exists?
      Resource.where(name: name).first
    else
      partner = build_partner(res_data["partner"])
      Resource.create(name: name, partner_id: partner.id)
    end
  end

  def build_partner(name)
    if Partner.where(short_name: name).exists?
      Partner.where(short_name: name).first
    else
      Partner.create(short_name: name, full_name: name)
    end
  end

  def build_rank(name)
    if Rank.where(name: name).exists?
      Rank.where(name: name).first
    else
      Rank.create(name: name)
    end
  end
end
