class Import::Page
  class << self
    def from_file(name)
      # Test with:
      # Import::Page.from_file(Rails.root.join("doc", "store-328598.json")) OR
      # Import::Page.from_file("http://beta.eol.org/store-328598.json")
      file =  if Uri.is_uri?(name.to_s)
                open(name) { |f| f.read }
              else
                File.read(name)
              end
      parse_page(JSON.parse(file))
      # NOTE: You mmmmmmight want to delete everything before you call this, but
      # I'm skipping that now. Sometimes you won't want to, anyway...
    end

      
    def parse_page(data)
      @resource_nodes = {}
      @page = Page.where(id: data["id"]).first_or_initialize do |pg|
        pg.id = data["id"]
      end
      page_node = TraitBank.create_page(@page.id)
      # TODO: pass a resource here. I started it but got lazy.
      node = build_node(data["native_node"])
      @page.native_node = node
      build_sci_name(ital: data["native_node"]["scientific_name"],
        canon: data["native_node"]["canonical_form"], node: node)
      data["vernaculars"].each { |cn| build_vernacular(cn, node) }
      @page.save
      last_position = 0
      if data["maps"]
        data["maps"].each do |m|
          build_map(m, node, last_position += 1)
        end
      end
      if data["articles"]
        data["articles"].each do |a|
          build_article(a, node, last_position += 1)
        end
      end
      if data["media"]
        data["media"].each do |m|
          build_image(m, node, last_position += 1)
        end
      end
      if data["collections"]
        data["collections"].each do |c|
          collection = build_collection(c)
          add_page_to_collection(collection)
        end
      end
      if data["traits"]
        data["traits"].each do |t_data|
          # NOTE: these are (currently) super-simple traits with no metadata!
          resource = build_resource(t_data["resource"])
          next if resource.nil? # NOTE: we don't import user-added data.
          unless Trait.exists?(resource.id, t_data["resource_pk"])
            pred = create_uri(t_data["predicate"])
            units = create_uri(t_data["units"]) if t_data["units"]
            term = create_uri(t_data["term"]) if t_data["term"]
            TraitBank.create_trait(page: page_node,
              supplier: @resource_nodes[resource.id],
              resource_pk: t_data["resource_pk"],
              scientific_name: t_data["scientific_name"],
              predicate: pred.uri,
              source: t_data["source"],
              measurement: t_data["measurement"],
              units: units ? units.uri : nil,
              term: term ? term.uri : nil,
              literal: t_data["literal"],
              object_page: t_data["object_page"]
            )
          end
        end
      end
      # TODO json_map ...we don't use it, yet, so leaving for later.
    end

    def create_uri(u_data)
      Uri.where(uri: u_data["uri"]).first_or_create do |uri|
        uri.name = u_data["name"]
        uri.uri = u_data["uri"]
        uri.name = u_data["name"]
        uri.definition = u_data["definition"]
        uri.comment = u_data["comment"]
        uri.attribution = u_data["attribution"]
        uri.is_hidden_from_overview = u_data["is_hidden_from_overview"]
        uri.is_hidden_from_glossary = u_data["is_hidden_from_glossary"]
      end
    end

    # NOTE: collections have no users associated from this scirpt. Doesn't matter
    # for demos.
    def build_collection(c_data)
      Collection.where(name: c_data["name"]).first_or_create do |c|
        c.name = c_data["name"]
        # TODO: Paperclip makes this hard: c.icon = c_data["icon"]
        c.description = c_data["description"]
      end
    end

    def add_page_to_collection(collection)
      CollectedPage.where(collection_id: collection.id,
          page_id: @page.id).first_or_create do |c|
        c.collection_id = collection.id
        c.page_id = @page.id
      end
    end

    def build_image(i_data, node, position)
      build_content(Medium, i_data, subclass: "image", format: "jpg", node: node,
        page: @page, position: position)
    end

    def build_article(a_data, node, position)
      section = build_section(a_data["section"])
      build_content(Article, a_data, node: node, page: @page, position: position,
        section: section)
    end

    def build_section(s_data)
      return nil if s_data.nil?
      Section.where(name: s_data["name"]).first_or_create do |s|
        s.name = s_data["name"]
        s.position = s_data["position"]
        s.parent = parent
      end
    end

    def build_map(m_data, node, position)
      build_content(Map, m_data, node: node, page: @page, position: position)
    end

    def build_content(klass, c_data, options = {})
      subclass = options[:subclass] || c_data.delete("type")
      ext = options[:format] || c_data.delete("format")
      # NOTE this only allows us to import ONE version of a single GUID, but
      # that's desirable: the website is intended to only contain published
      # versions of data.
      if klass.where(guid: c_data["guid"]).exists?
        klass.where(guid: c_data["guid"]).first
      else
        resource = build_resource(c_data["provider"])
        return nil if resource.nil?
        # Common fields for all content:
        hash = {
          guid: c_data["guid"],
          resource_pk: c_data["resource_pk"],
          provider: resource,
          license: build_license(c_data["license"]),
          bibliographic_citation: build_citation(c_data["bibliographic_citation"]),
          owner: c_data["owner"],
          name: c_data["name"],
          source_url: c_data["source_url"]
        }
        # Type-specific fields:
        hash[:description] = c_data["description"] if
          c_data["description"]
        hash[:body] = c_data["body"] if c_data["body"]
        hash[:base_url] = c_data["base_url"] if c_data["base_url"]
        hash[:section_id] = options[:section].id if options[:section]
        hash[:subclass] = subclass if subclass # Not always needed.
        hash[:format] = ext if ext # Not always needed.
        hash[:language] = build_language(c_data["language"]) if
          c_data["language"]
        content = klass.create(hash)
        PageContent.create(
          page: @page,
          source_page: @page,
          position: options["position"],
          content: content,
          trust: :trusted
        )
        # TODO: this wasn't working, and isn't needed yet.
        # options[:node].ancestors.each do |ancestor|
        #   # TODO: we will have to figure out a proper algorithm for position. :S
        #   pos = PageContent.where(page_id: ancestor.page_id).maximum(:position) || 0
        #   pos += 1
        #   PageContent.create(
        #     page_id: ancestor.page_id,
        #     source_page: @page,
        #     position: pos,
        #     content: content,
        #     trust: :trusted
        #   )
        # end
        content
      end
    end

    def build_node(node_data, resource = nil)
      resource ||= build_resource(node_data["resource"])
      Node.where(resource_id: resource.id, resource_pk: node_data["resource_pk"]).
           first_or_create do |n|
        parent =  if node_data["parent"]
                    build_node(node_data["parent"], resource)
                  else
                    nil
                  end

        build_rank(node_data["rank"])
        n.id = node_data["id"],
        n.resource_id = resource.id
        n.page_id = node_data["page_id"]
        # These get calculated, sadly. ...TODO: override.
        # n.lft = node_data["lft"]
        # n.rgt = node_data["rgt"]
        n.scientific_name = node_data["scientific_name"] # denormalized
        n.canonical_form = node_data["canonical_form"]
        n.resource_pk = node_data["resource_pk"]
        n.source_url = node_data["source_url"]
        n.is_hidden = false
        n.parent_id = parent ? parent.id : nil
      end
    end

    def build_sci_name(opts)
      ScientificName.where(italicized: opts[:ital]).first_or_create do |sn|
        sn.italicized = opts[:ital]
        sn.canonical_form = opts[:canon]
        sn.page_id = @page.id
        sn.node_id = opts[:node].id
        sn.is_preferred = true
        sn.taxonomic_status_id = TaxonomicStatus.preferred.id
      end
    end

    def build_vernacular(v_data, node)
      lang = build_language(v_data["language"])
      Vernacular.where(string: v_data["string"], language_id: lang.id, node_id: node.id).first_or_create do |v|
        v.string = v_data["string"]
        v.language_id = lang.id
        v.node_id = node.id
        v.page_id = @page.id
        # TODO: Hmmmn... I was getting more than one per page per language. :S
        v.is_preferred = v_data["preferred"]
        v.is_preferred_by_resource = v_data["preferred"]
      end
    end

    def build_language(code)
      Language.where(code: code).first_or_create do |l|
        l.code = code
        l.group = code[0..1]
      end
    end

    def build_license(l_data)
      License.where(source_url: l_data["source_url"]).first_or_create do |l|
        l.source_url = l_data["source_url"]
        l.name = l_data["name"]
        l.icon_url = l_data["icon_url"]
        l.can_be_chosen_by_partners = l_data["can_be_chosen_by_partners"]
      end
    end

    def build_resource(res_data)
      return nil if res_data.nil?
      name = res_data["name"]
      resource = Resource.where(name: name).first_or_create do |r|
        partner = build_partner(res_data["partner"])
        r.name = name
        r.partner_id = partner.id
      end
      @resource_nodes[resource.id] = TraitBank.create_resource(resource.id)
      resource
    end

    def build_partner(name)
      Partner.where(short_name: name).first_or_create do |p|
        p.short_name = name
        p.full_name = name
      end
    end

    def build_rank(name)
      Rank.where(name: name).first_or_create do |r|
        r.name = name
      end
    end

    def build_citation(citation)
      BibliographicCitation.where(body: citation).first_or_create do |cit|
        cit.body = citation
      end
    end
  end
end
