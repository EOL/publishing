# Abstraction between our traits and the implementation of thir storage. ATM, we
# use neo4j.
class TraitBank

  # The Labels, and their expected relationships { and properties (*required) }:
  # * Resource: { *resource_id }
  # * Page: ancesor(Page), parent(Page), trait(Trait) { *page_id }
  # * Trait: supplier(Resource), metadata(MetaData)
  #     { *resource_pk, *scientific_name, *predicate,
  #       statistical_method, sex, lifestage, source, measurement, units,
  #       object_page, literal, term }
  # * MetaData: { *predicate, measurement, units, lietral, term }

  # Indexes (TODO: probably expand on this):
  # CREATE INDEX ON :Page(page_id);
  # CREATE INDEX ON :Trait(resource_id, resource_pk);
  # CREATE INDEX ON :Trait(predicate);
  # CREATE INDEX ON :MetaData(predicate);
  # CREATE CONSTRAINT ON (o:Page) ASSERT o.id IS UNIQUE;
  # CREATE CONSTRAINT ON (o:Trait) ASSERT o.resource_id, o.resource_pk IS UNIQUE;
  # Can we create a constraint where a Trait only has one of [measurement, page,
  #   literal, term]?

  if false
    tbank = TraitBank.connection
    tbank.create_schema_index("Page", ["page_id"])
    tbank.create_schema_index("Trait", ["resource_pk"])
    tbank.create_schema_index("Trait", ["predicate"])
    tbank.create_schema_index("MetaData", ["predicate"])
    tiger_page = tbank.create_node("page_id" => 328674)
    tbank.add_label(tiger_page, "Page")
    pantheria_mlh_resource = tbank.create_node("resource_id" => 704)
    tbank.add_label(pantheria_mlh_resource, "Resource")
    geo_range_km2 = tbank.create_node("resource_pk" => 691746, # I made up that id
      "scientific_name" => "Panthera tigris",
      "predicate" => "http://eol.org/schema/terms/GeographicRangeArea",
      "source" => "Data set supplied by Kate E. Jones. The data can also etc...",
      "measurement" => "2494993.45",
      "units" => "http://eol.org/schema/terms/squarekilometer")
    tbank.add_label(geo_range_km2, "Trait")
    tbank.create_relationship("trait", tiger_page, geo_range_km2)
    # Not very helpful, but possible:
    page_res = tbank.find_nodes_labeled("Page", {:page_id => 328674})
    # Same, as a query... slower, unforunately, though it seems it should
    # auto-detect and use the index:
    res = tbank.execute_query("MATCH (page:Page { page_id: 328674 }) RETURN page")
    # This works... obviously with no metadata:
    res = tbank.execute_query("MATCH (page:Page { page_id: 328674 }) "\
      "MATCH (page)-[:trait]->(trait) "\
      "RETURN trait")
    md1 = tbank.create_node(predicate: "http://purl.org/dc/terms/bibliographicCitation",
      literal: "Kate E. Jones, Jon Bielby, Marcel Cardillo, Susanne A. Fritz, etc...")
    tbank.add_label(md1, "MetaData")
    tbank.create_relationship("metadata", geo_range_km2, md1)
    # This works, too, but ONLY if there IS metadata for each trait! So, we need
    # an optional...
    res = tbank.execute_query("MATCH (page:Page { page_id: 328674 }) "\
      "MATCH (page)-[:trait]->(trait) "\
      "MATCH (trait)-[:metadata]->(meta) "\
      "RETURN trait, meta")
    # Or, more succinctly:
    res = tbank.execute_query("MATCH (page:Page { page_id: 328674 }) "\
      "MATCH (page)-[:trait]->(trait)-[:metadata]->(meta) "\
      "RETURN trait, meta")
    # Even moreso:
    res = tbank.execute_query("MATCH (page:Page { page_id: 328674 })-[:trait]->(trait)-[:metadata]->(meta) "\
      "RETURN trait, meta")
    # But it turns out the optional requires a second clause, so:
    res = tbank.execute_query("MATCH (page:Page { page_id: 328674 })-[:trait]->(trait) "\
      "OPTIONAL MATCH (trait)-[:metadata]->(meta) "\
      "RETURN trait, meta")


  end

  class << self
    @connected = false

    # REST-style:
    def connection
      @connection ||= Neography::Rest.new(ENV["EOL_TRAITBANK_URL"])
      @connected = true
    end

    # Neography-style:
    def connect
      parts = ENV["EOL_TRAITBANK_URL"].split(%r{[/:@]})
      Neography.configure do |cfg|
        cfg.username = parts[3]
        cfg.password = parts[4]
      end
    end

    def trait_exists?(resource_id, pk)
      # TODO, maybe Neography::Node.find("trait_index", "id", id)
    end
  end
end
