class Import::Page
  class << self
    def from_file(name)
      # Test with:
      # Import::Page.from_file(Rails.root.join("doc", "store-328598.json")) OR
      # Import::Page.from_file("http://beta.eol.org/store-328598.json")
      file = if Uri.is_uri?(name.to_s)
               open(name) { |f| f.read }
             else
               File.read(name)
             end
      parse_page(JSON.parse(file))
      # NOTE: You mmmmmmight want to delete everything before you call this, but
      # I'm skipping that now. Sometimes you won't want to, anyway...
    end

    # TODO: pass a resource here. I started it but got lazy.
    def create_page(id, node_data, name, canon)
      @page = Page.where(id: id).first_or_initialize do |pg|
        pg.id = id
      end
      puts "Created page: #{@page.id}"
      page_node = TraitBank.create_page(@page.id)
      node = build_node(node_data)
      @page.native_node = node
      build_sci_name(ital: name, canon: canon, node: node)
      @page.save
      return node, page_node
    end

    def parse_page(data)
      @resource_nodes = {}
      @roles = {}
      node, page_node = create_page(data["id"],
        data["native_node"],
        data["native_node"]["scientific_name"],
        data["native_node"]["canonical_form"])
      data["scientific_synonyms"].each {|sy| build_sci_name(ital: sy["italicized"], canon: sy["canonical"],
                                        synonym: true, preferred: sy["preferred"], node: node)}
      data["vernaculars"].each { |cn| build_vernacular(cn, node) }
      data["nonpreferred_scientific_names"].each {|sn| build_sci_name(ital: sn["italicized"], canon: sn["canonical"],
                                     synonym: false, preferred: sn["preferred"], node: node)}
      last_position = 0
      if data["articles"]
        data["articles"].each do |a|
          # Some articles don't have a body:
          a["body"] ||= "Ooops, body missing"
          build_article(a, node, last_position += 1)
        end
        puts ".. #{data["articles"].size} articles"
      end
      if data["media"]
        data["media"].each do |m|
          build_image(m, node, last_position += 1)
        end
        puts ".. #{data["media"].size} media"
      end
      if data["maps"]
        data["maps"].each do |m|
          build_map(m, node, last_position += 1)
        end
        puts ".. #{data["maps"].size} maps"
      end
      if data["collections"]
        data["collections"].each do |c|
          collection = build_collection(c)
          add_page_to_collection(collection)
        end
        puts ".. #{data["collections"].size} collections"
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
            obj_page_id = nil
            if t_data["object_page"]
              obj_page_id = t_data["object_page"]["id"]
              create_page(obj_page_id,
                t_data["object_page"]["node"],
                t_data["object_page"]["scientific_ name"],
                t_data["object_page"]["canonical_form"])
            end
            meta = []
            if t_data["metadata"]
              t_data["metadata"].each do |md|
                mpred = create_uri(md["predicate"])
                next unless mpred
                munits = create_uri(md["units"]) if md["units"]
                mmeas = md["measurement"] if md["measurement"]
                mterm = create_uri(md["term"]) if md["term"]
                mlit = md["literal"]
                meta << { predicate: mpred, units: munits, measurement: mmeas,
                  term: mterm, literal: mlit }
              end
            end
            TraitBank.create_trait(page: page_node,
              supplier: @resource_nodes[resource.id],
              resource_pk: t_data["resource_pk"],
              scientific_name: t_data["scientific_name"] || @page.scientific_name,
              predicate: pred,
              source: t_data["source"],
              measurement: t_data["measurement"],
              statistical_method: t_data["statistical_method"],
              lifestage: t_data["lifestage"],
              sex: t_data["sex"],
              units: units,
              object_term: term,
              literal: t_data["literal"],
              object_page_id: obj_page_id,
              metadata: meta
            )
          end
        end
        puts ".. #{data["traits"].size} traits"
      end
      # TODO json_map ...we don't use it, yet, so leaving for later.
    end

    def create_uri(u_data)
      TraitBank.create_term(u_data.symbolize_keys)
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
      build_content(Medium, m_data, node: node, page: @page, position: position,
        subclass: :map)
    end

    def build_content(klass, c_data, options = {})
      subclass = options[:subclass] || c_data.delete("type")
      ext = options[:format] || c_data.delete("format")
      # NOTE this only allows us to import ONE version of a single GUID, but
      # that's desirable: the website is intended to only contain published
      # versions of data.
      content = if klass.where(guid: c_data["guid"]).exists?
        klass.where(guid: c_data["guid"]).first
      else
        resource = build_resource(c_data["provider"])
        return nil if resource.nil?
        attributions = c_data.delete("attributions")
        # Common fields for all content:
        hash = {
          guid: c_data["guid"],
          resource_pk: c_data["resource_pk"],
          resource: resource,
          license: build_license(c_data["license"]),
          rights_statement: c_data["rights_statement"],
          location: build_location(c_data["location"]),
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
        c = klass.create(hash)
        add_attributions(c, attributions)
        c
      end
      begin
        PageContent.create(
          page: @page,
          source_page: @page,
          position: options["position"],
          content: content,
          trust: :trusted
        )
      rescue
        # Don't care
      end
      options[:node].ancestors.each do |ancestor|
        # TODO: we will have to figure out a proper algorithm for position. :S
        pos = PageContent.where(page_id: ancestor.page_id).maximum(:position) || 0
        pos += 1
        begin
          PageContent.create(
            page_id: ancestor.page_id,
            source_page: @page,
            position: pos,
            content: content,
            trust: :trusted
          )
        rescue
          # Don't care...
        end
      end
      content
    end

    # { role: attrib.agent_role.label, url: url, value: attrib.agent.full_name }
    def add_attributions(content, attributions)
      return if attributions.nil?
      attributions.each do |attribution|
        role = build_role(attribution["role"])
        attribution = Attribution.create(role: role, url: attribution["url"],
          value: attribution["value"])
        attribution.content = content
      end
    end

    def build_role(name)
      @roles[name] ||= Role.where(name: name).first_or_create do |r|
        r.name = name
      end
    end

    def build_location(l_data)
      return nil if l_data.nil? or l_data.empty?
      attrs = {
        location: l_data["verbatim"],
        longitude: l_data["long"],
        latitude: l_data["lat"]
      }
      Location.where(location: l_data["verbatim"], longitude: l_data["long"],
                     latitude: l_data["lat"]).first_or_create do |l|
        l.location: l_data["verbatim"],
        l.longitude: l_data["long"],
        l.latitude: l_data["lat"]
      end
    end

    def build_node(node_data, resource = nil)
      resource ||= build_resource(node_data["resource"])
      TraitBank.create_node_in_hierarchy(node_data["node_id"].to_i, @page.id)
      Node.where(resource_id: resource.id, resource_pk: node_data["resource_pk"]).
           first_or_create do |n|
        parent =  if node_data["parent"]
                    build_node(node_data["parent"], resource)
                  else
                    nil
                  end

        TraitBank.adjust_node_parent_relationship(node_data["node_id"],
              node_data["parent"]["node_id"]) if node_data["node_id"] && node_data["parent"]\
              && node_data["parent"]["node_id"]

        build_rank(node_data["rank"])
        n.id = node_data["id"],
        n.resource_id = resource.id
        n.page_id = node_data["page_id"]
        # These get calculated, sadly. ...TODO: override.
        # n.lft = node_data["lft"]
        # n.rgt = node_data["rgt"]
        n.scientific_name = node_data["scientific_name"] # denormalized
        n.canonical_form = node_data["canonical_form"]
        n.resource_pk = node_data["resource_pk"] || node_data["scientific_name"]
        n.source_url = node_data["source_url"]
        n.is_hidden = false
        n.parent_id = parent ? parent.id : nil
      end
    end

    def build_sci_name(opts)
      opts[:italicized] ||= opts[:canon] # Was missing in some Betula nigra records...
      ScientificName.where(italicized: opts[:ital], is_preferred: opts[:preferred]).first_or_create do |sn|
        sn.italicized = opts[:ital]
        sn.canonical_form = opts[:canon]
        sn.page_id = @page.id
        sn.node_id = opts[:node].id
        if opts[:preferred].nil?
          sn.is_preferred = true
          sn.taxonomic_status_id = TaxonomicStatus.preferred.id
        else
          sn.is_preferred = opts[:preferred]
          opts[:synonym] ? sn.taxonomic_status_id = TaxonomicStatus.synonym.id : sn.taxonomic_status_id = TaxonomicStatus.misnomer.id
        end
      end
    end

    def build_vernacular(v_data, node)
      lang = build_language(v_data["language"])
      # TODO: Create a funtion to parse vetted information and set 'trust attribute accordingly'
      Vernacular.where(string: v_data["string"], language_id: lang.id, node_id: node.id).create do |v|
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
      name ||= "unknown" # Sigh.
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
