class Import::Page
  def from_file(name)
    # Test with name = '/Users/jrice/Downloads/store-328598.json'
    file = File.read(name)
    data = JSON.parse(file)
    # You prrrrrobly want to delete everything before you call this, but I'm
    # skipping that now.
    page = Page.create(id: data["id"])
    node = build_node(data["native_node"], page)
    build_sci_name(ital: data["native_node"]["scientific_name"],
      canon: data["native_node"]["canonical_form"], node: node, page: page)
    data["vernaculars"].each { |cn| build_vernacular(cn, node, page) }
    # YOU WERE HERE ... TODO media articles traits collections json_map maps
    page.save!
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
      Node.new(id: node_data["id"],
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
