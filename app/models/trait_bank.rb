# Abstraction between our traits and the implementation of thir storage. ATM, we
# use neo4j.
#
# NOTE: in its current state, this is NOT done! Neography uses a plain hash to
# store objects, and ultimately we're going to want our own models to represent
# things. But in these early testing stages, this is adequate. Since this is not
# its final form, there are no specs yet. ...We need to feel out how we want
# this to work, first.
class TraitBank

  # The Labels, and their expected relationships { and (*required)properties }:
  # * Resource: { *resource_id }
  # * Page: ancestor(Page), parent(Page), trait(Trait) { *page_id }
  # * Trait: *predicate_term(Term), *supplier(Resource), metadata(MetaData),
  #          object_term(Term)
  #     { *resource_pk, *scientific_name, statistical_method, sex, lifestage,
  #       source, measurement, units, object_page_id, literal }
  # * MetaData: { *predicate, measurement, units, lietral, term }

  # * Term (or URI, not sure) ...relationships...
  #     { *uri, *name, *section_ids(csv), definition, comment, attribution,
  #       is_hidden_from_overview, is_hidden_from_glossary }


  # Indexes (TODO: probably expand on this):
  # CREATE INDEX ON :Page(page_id);
  # CREATE INDEX ON :Trait(resource_pk);
  # CREATE INDEX ON :Trait(predicate);
  # CREATE INDEX ON :Term(predicate);
  # CREATE INDEX ON :MetaData(predicate);
  # CREATE CONSTRAINT ON (o:Page) ASSERT o.id IS UNIQUE;
  # CREATE CONSTRAINT ON (o:Term) ASSERT o.uri IS UNIQUE;
  # CREATE CONSTRAINT ON (o:Trait) ASSERT o.resource_id, o.resource_pk IS UNIQUE;
  # Can we create a constraint where a Trait only has one of [measurement,
  #   object_page_id, literal, term]?

  class << self
    @connected = false

    # REST-style:
    def connection
      @connection ||= Neography::Rest.new(ENV["EOL_TRAITBANK_URL"])
      @connected = true
      @connection
    end

    # Neography-style:
    def connect
      parts = ENV["EOL_TRAITBANK_URL"].split(%r{[/:@]})
      Neography.configure do |cfg|
        cfg.username = parts[3]
        cfg.password = parts[4]
      end
    end

    def quote(string)
      return string if string.is_a?(Numeric) || string =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
      %Q{"#{string.gsub(/"/, "\\\"")}"}
    end

    # Your gun, your foot:
    def nuclear_option!
      connection.execute_query("MATCH (n) DETACH DELETE n")
    end

    def trait_exists?(resource_id, pk)
      res = connection.execute_query("MATCH (trait:Trait { resource_pk: #{quote(pk)} })"\
        "-[:supplier]->(res:Resource { resource_id: #{resource_id} }) "\
        "RETURN trait")
      res["data"] ? res["data"].first : false
    end

    def page_exists?(page_id)
      res = connection.execute_query("MATCH (page:Page { page_id: #{page_id} })"\
        "RETURN page")
      res["data"] ? res["data"].first : false
    end

    def by_page(page_id)
      res = connection.execute_query(
        "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait)"\
          "-[:supplier]->(resource:Resource) "\
        "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData) "\
        "RETURN resource, trait, meta"
      )
      # Neography recognizes the objects we get back, but the format is weird
      # for building pages, so I transform it here (temporarily, for
      # simplicity):
      build_trait_array(res, [:resource, :trait, :meta])
    end

    def by_predicate(predicate)
      res = connection.execute_query(
        "MATCH (page:Page)-[:trait]->(trait:Trait { predicate: \"#{predicate}\" })"\
          "-[:supplier]->(resource:Resource) "\
        "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData) "\
        "RETURN resource, trait, page, meta"
      )
      build_trait_array(res, [:resource, :trait, :page, :meta])
    end

    # The problem is that the results are in a kind of "table" format, where
    # columns on the left are duplicated to allow for multiple values on the
    # right. This detects those duplicates to add them (as an array) to the
    # trait, and adds all of the other data together into one object meant to
    # represent a single trait, and then returns an array of those traits. It's
    # really not as complicated as it seems! This is mostly bookkeeping.
    def build_trait_array(results, cols)
      traits = []
      previous_id = nil
      resource_col = cols.find_index(:resource)
      trait_col = cols.find_index(:trait)
      page_col = cols.find_index(:page)
      meta_col = cols.find_index(:meta)
      results["data"].each do |trait_res|
        resource_id = trait_res[resource_col]["data"]["resource_id"]
        trait = trait_res[trait_col]["data"]
        page = page_col ? trait_res[page_col]["data"] : nil
        meta_data = trait_res[meta_col] ? trait_res[meta_col]["data"] : nil
        this_id = "#{resource_id}:#{trait["resource_pk"]}"
        this_id += ":#{page["page_id"]}" if page
        if this_id == previous_id
          # the conditional at the end of this phrase actually detects duplicate
          # nodes, which we shouldn't have but I was getting in early tests:
          traits.last[:metadata] << symbolize_hash(meta_data) if meta_data
        else
          trait[:metadata] = meta_data ? [ symbolize_hash(meta_data) ] : nil
          trait[:page_id] = page["page_id"] if page
          trait[:resource_id] = resource_id if resource_id
          trait[:id] = this_id
          traits << symbolize_hash(trait)
        end
        previous_id = this_id
      end
      traits
    end

    def glossary(traits)
      uris = Set.new
      traits.each do |trait|
        uris << trait[:predicate] if trait[:predicate]
        uris << trait[:units] if trait[:units]
        uris << trait[:term] if trait[:term]
      end
      glossary = Uri.where(uri: uris.to_a)
      Hash[ *glossary.map { |u| [ u.uri, u ] }.flatten ]
    end

    def resources(traits)
      resources = Resource.where(id: traits.map { |t| t[:resource_id] }.compact.uniq)
      Hash[ *resources.map { |r| [ r.id, r ] }.flatten ]
    end

    def symbolize_hash(hash)
      hash.inject({}) { |memo,(k,v)| memo[k.to_sym] = v; memo }
    end

    def create_page(id)
      if page = page_exists?(id)
        return page
      end
      page = connection.create_node(page_id: id)
      connection.add_label(page, "Page")
      page
    end

    def create_resource(id)
      resource = connection.create_node(resource_id: id)
      connection.add_label(resource, "Resource")
      resource
    end

    def create_trait(options)
      page = options.delete(:page)
      supplier = options.delete(:supplier)
      meta = options.delete(:meta_data)
      trait = connection.create_node(options)
      connection.add_label(trait, "Trait")
      connection.create_relationship("trait", page, trait)
      connection.create_relationship("supplier", trait, supplier)
      meta.each { |md| add_metadata_to_trait(trait, md) } if meta
      trait
    end

    def add_metadata_to_trait(trait, options)
      meta = connection.create_node(options)
      connection.add_label(meta, "MetaData")
      connection.create_relationship("metadata", trait, meta)
      meta
    end

    def sort(traits, glossary)
      traits.sort do |a,b|
        name_a = a && glossary[a[:predicate]].try(:name)
        name_b = b && glossary[b[:predicate]].try(:name)
        if name_a && name_b
          if name_a == name_b
            # TODO: associations
            if a[:literal] && b[:literal]
              a[:literal].downcase.gsub(/<\/?[^>]+>/, "") <=>
                b[:literal].downcase.gsub(/<\/?[^>]+>/, "")
            elsif a[:measurement] && b[:measurement]
              a[:measurement] <=> b[:measurement]
            else
              trait_a = glossary[a[:trait]].try(:name)
              trait_b = glossary[b[:trait]].try(:name)
              if trait_a && trait_b
                trait_a.downcase <=> trait_b.downcase
              elsif trait_a
                -1
              elsif trait_b
                1
              else
                0
              end
            end
          else
            name_a.downcase <=> name_b.downcase
          end
        elsif name_a
          -1
        elsif name_b
          1
        else
          0
        end
      end
    end
  end
end
