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
  # * Page: ancesor(Page), parent(Page), trait(Trait) { *page_id }
  # * Trait: supplier(Resource), metadata(MetaData)
  #     { *resource_pk, *scientific_name, *predicate,
  #       statistical_method, sex, lifestage, source, measurement, units,
  #       object_page_id, literal, term }
  # * MetaData: { *predicate, measurement, units, lietral, term }

  # Indexes (TODO: probably expand on this):
  # CREATE INDEX ON :Page(page_id);
  # CREATE INDEX ON :Trait(resource_pk);
  # CREATE INDEX ON :Trait(predicate);
  # CREATE INDEX ON :MetaData(predicate);
  # CREATE CONSTRAINT ON (o:Page) ASSERT o.id IS UNIQUE;
  # CREATE CONSTRAINT ON (o:Trait) ASSERT o.resource_id, o.resource_pk IS UNIQUE;
  # Can we create a constraint where a Trait only has one of [measurement,
  #   object_page_id, literal, term]?

  # This was my testing code. We'll remove it, soon:
  if false
    connection = TraitBank.connection
    # Set up a few indexes for speed:
    connection.create_schema_index("Page", ["page_id"])
    connection.create_schema_index("Trait", ["resource_pk"])
    connection.create_schema_index("Trait", ["predicate"])
    connection.create_schema_index("MetaData", ["predicate"])

    # Create the basic stuff:
    page_id = 328674
    tiger_page = TraitBank.create_page(page_id)
    pantheria_mlh_resource = TraitBank.create_resource(704)
    biome_resource = TraitBank.create_resource(976)
    iucn_resource = TraitBank.create_resource(737)

    # Now add a trait with two bits of metadata and a numeric value:
    geo_range_km2 = TraitBank.create_trait(
      page: tiger_page,
      supplier: biome_resource,
      resource_pk: 691746, # I made up that id
      scientific_name: "Panthera tigris",
      predicate: "http://eol.org/schema/terms/GeographicRangeArea",
      source: "Data set supplied by Kate E. Jones. The data can also etc...",
      measurement: "2494993.45",
      units: "http://eol.org/schema/terms/squarekilometer",
      meta_data: [
        {
          predicate: "http://purl.org/dc/terms/bibliographicCitation",
          literal: "Kate E. Jones, Jon Bielby, Marcel Cardillo, Susanne A. Fritz, etc..."
        }, {
          predicate: "http://rs.tdwg.org/dwc/terms/measurementMethod",
          literal: "Geographic Range (Area): Digital geographic range maps of all extant, "\
            "non-marine mammals from Sechrest (2003) etc..."
        }
      ]
    )

    # Second trait has only one bit of metadata and a term value:
    present_meadow = TraitBank.create_trait(
      page: tiger_page,
      supplier: pantheria_mlh_resource,
      resource_pk: 7466911, # I made up that id
      scientific_name: "Panthera tigris",
      predicate: "http://eol.org/schema/terms/Present",
      source: "http://www.worldwildlife.org/publications/wildfinder-database",
      term: "http://eol.org/schema/terms/Amur_meadow_steppe",
      meta_data: [{ predicate: "http://purl.org/dc/terms/bibliographicCitation",
        literal: "Kate E. Jones, Jon Bielby, Marcel Cardillo, Susanne A. Fritz, etc..." }] )

    # Third trait with no metdata and a literal value:
    pop_trend = TraitBank.create_trait(
      page: tiger_page,
      supplier: iucn_resource,
      resource_pk: "Panthera tigris",
      scientific_name: "Panthera tigris (Linnaeus, 1758)",
      predicate: "http://iucn.org/population_trend",
      source: "http://www.iucnredlist.org/apps/redlist/details/15955",
      literal: "Decreasing")

    # TODO: object_page / relationships (e.g.: consumes).

    # Not very helpful (lots of weird attributes), but possible:
    page_res = connection.find_nodes_labeled("Page", { page_id: page_id })
    # Same, as a query... slower, unforunately, though it seems it should
    # auto-detect and use the index; perhaps it's building models that take
    # longer, will have to try it at scale:
    res = connection.execute_query("MATCH (page:Page { page_id: 328674 }) RETURN page")
    # This works to get everything for a page:
    page_id ||= 328674
    traits = TraitBank.by_page(page_id)
  end

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
      resources = Resource.where(uri: traits.map { |t| t[:resource_id] }.compact)
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
  end
end
