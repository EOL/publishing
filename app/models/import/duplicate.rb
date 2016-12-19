class Import::Duplicate
  class << self
    def duplicate_from_file(name, num_of_pages)
      # Test with:
      # Import::Duplicate.duplicate_from_file(Rails.root.join("doc", "store-328598.json"), 1) OR
      # Import::Duplicate.duplicate_from_file("http://beta.eol.org/store-328598.json")
      file = if Uri.is_uri?(name.to_s)
               open(name) { |f| f.read }
             else
               File.read(name)
             end
      for i in 1..num_of_pages
        parse_page(JSON.parse(file), i)
      end
    end


  def parse_page(data, i)
    @resource_nodes = {}
      node, page_node = create_page( Page.maximum("id") + 1,
        data["native_node"],
        "#{data["native_node"]["scientific_name"]}-#{i}",
        "#{data["native_node"]["canonical_form"]}-#{i}", i)
      data["vernaculars"].each { |cn| build_vernacular(cn, node) }
      if data["traits"]
        data["traits"].each do |t_data|
          # NOTE: these are (currently) super-simple traits with no metadata!
          resource = build_resource(t_data["resource"])
          next if resource.nil? # NOTE: we don't import user-added data.
          unless Trait.exists?(resource.id, "#{t_data["resource_pk"]}#{i}") #ddddddddddddddddddddddddddddd
            pred = create_uri(t_data["predicate"])
            units = create_uri(t_data["units"]) if t_data["units"]
            term = create_uri(t_data["term"]) if t_data["term"]
            obj_page_id = nil
            if t_data["object_page"]
              obj_page_id = t_data["object_page"]["id"]
              create_page(obj_page_id,
                t_data["object_page"]["node"],
                t_data["object_page"]["scientific_name"],
                t_data["object_page"]["canonical_form"], nil)
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
              resource_pk: "#{t_data["resource_pk"]}#{i}",#ddddddddddddddddddddddddddddddddddddddddddd
              scientific_name: "#{t_data["scientific_name"]}-#{i}" || @page.scientific_name,
              predicate: pred,
              source: t_data["source"],
              measurement: t_data["measurement"],
              statistical_method: t_data["statistical_method"],
              lifestage: t_data["lifestage"],
              sex: t_data["sex"],
              scientific_name: "#{t_data["scientific_name"]}-#{i}",
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
    
    
    
    
    def create_page(id, node_data, name, canon, i)
      @page = Page.where(id: id).first_or_initialize do |pg|
        pg.id = id
      end
      puts "Created page: #{@page.id}"
      page_node = TraitBank.create_page(@page.id)
      node = build_node(node_data, nil, i)
      @page.native_node = node
      build_sci_name(ital: name, canon: canon, node: node)
      @page.save
      return node, page_node
    end

    def create_uri(u_data)
      TraitBank.create_term(u_data.symbolize_keys)
    end

    def build_node(node_data, resource = nil, i)
      resource ||= build_resource(node_data["resource"])
      TraitBank.create_node_in_hierarchy(node_data["node_id"].to_i, @page.id)
      Node.where(resource_id: resource.id, resource_pk: "#{node_data["resource_pk"]}#{i}").
           first_or_create do |n|
        parent =  if node_data["parent"]
                    build_node(node_data["parent"], resource, nil)
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
        n.scientific_name = "#{node_data["scientific_name"]}-#{i}}" # denormalized
        n.canonical_form = "#{node_data["canonical_form"]}-#{i}}"
        n.resource_pk = "#{node_data["resource_pk"]}#{i}" ||  "#{node_data["scientific_name"]}-#{i}}"
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
      Vernacular.where(string: "#{v_data["string"]}-A", language_id: lang.id, node_id: node.id).first_or_create do |v|
        v.string = "#{v_data["string"]}-A"
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

  end
end
