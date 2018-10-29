# Generate CSV files expressing trait information for a single taxon
# recursively.

require 'csv'
require 'fileutils'

class TraitBank::TraitsDumper
  def self.dump_clade(clade_page_id, dest, csvdir, limit)
    new(clade_page_id, dest, csvdir, limit).doit
  end
  def initialize(clade_page_id, dest, csvdir, limit)
    @clade = Integer(clade_page_id)
    @dest = dest
    @csvdir = csvdir
    @limit = Integer(limit)
  end
  def doit
    write_zip [spew_pages,
               spew_traits,
               spew_metadatas,
               spew_terms]
  end

  # There is probably a way to do this without creating the temporary
  # files at all.
  def write_zip(paths)
    File.delete(@dest) if File.exists?(@dest)
    Zip::File.open(@dest, Zip::File::CREATE) do |zipfile|
      directory = "trait_bank"
      zipfile.mkdir(directory)
      paths.each do |path|
        name = File.basename(path)
        STDERR.puts "storing #{name} into zip file"
        zipfile.add(File.join(directory, name), path)
      end
      # Put it on its own line for easier cut/paste
      STDERR.puts @dest
    end
  end

  #---- Query #3: Pages

  def spew_pages

    pages_query =
     "MATCH (page:Page)-[:parent*]->(clade:Page {page_id: #{@clade}})
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (page)-[:parent]->(parent:Page)
      RETURN page.page_id, parent.page_id, page.canonical 
      LIMIT #{@limit}"

    pages_keys = ["page_id", "parent_id", "canonical"] #fragile

    pages_result = TraitBank.query(pages_query)

    spew_csv(pages_result, pages_keys, "pages.csv")

  end

  #---- Query #2: Traits

  def spew_traits

    traits_query =
     "MATCH (t:Trait)<-[:trait]-(page:Page),
            (page)-[:parent*]->(clade:Page {page_id: #{@clade}})
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (t)-[:supplier]->(r:Resource)
      OPTIONAL MATCH (t)-[:predicate]->(predicate:Term)
      OPTIONAL MATCH (t)-[:object_term]->(obj:Term)
      OPTIONAL MATCH (t)-[:normal_units_term]->(normal_units:Term)
      OPTIONAL MATCH (t)-[:units_term]->(units:Term)
      RETURN t.eol_pk, page.page_id, r.resource_pk, r.resource_id,
             t.source, t.scientific_name, predicate.uri,
             t.object_page_id, obj.uri,
             t.normal_measurement, normal_units.uri, t.normal_units, 
             t.measurement, units.uri, t.units, 
             t.literal
      LIMIT #{@limit}"

    # Matching the keys used in the tarball if possible (even when inconsistent)
    # E.g. should "predicate" be "predicate_uri" ?

    traits_keys = ["eol_pk", "page_id", "resource_pk", "resource_id",
                   "source", "scientific_name", "predicate",
                   "object_page_id", "value_uri",
                   "normal_measurement", "normal_units_uri", "normal_units",
                   "measurement", "units_uri", "units",
                   "literal"]

    traits_result = TraitBank.query(traits_query)

    spew_csv(traits_result, traits_keys, "traits.csv")

  end

  #---- Query #1: Metadatas

  def spew_metadatas

    metadata_query = 
     "MATCH (m:MetaData)<-[:metadata]-(t:Trait),
            (t)<-[:trait]-(page:Page),
            (page)-[:parent*]->(clade:Page {page_id: #{@clade}})
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (m)-[:predicate]->(predicate:Term)
      OPTIONAL MATCH (m)-[:object_term]->(obj:Term)
      OPTIONAL MATCH (m)-[:units_term]->(units:Term)
      RETURN m.eol_pk, t.eol_pk, predicate.uri, obj.uri, m.measurement, units.uri, m.literal
      LIMIT #{@limit}"

    metadata_keys = ["eol_pk", "trait_eol_pk", "predicate", "value_uri",
                     "measurement", "units_uri", "literal"]
    metadata_result = TraitBank.query(metadata_query)

    spew_csv(metadata_result, metadata_keys, "metadata.csv")

  end

  #---- Query #0: Terms

  def spew_terms

    # Many Term nodes have 'uri' properties that are not URIs.  Would it 
    # be useful to filter those out?  It's about 2% of the nodes.

    # I'm not sure where there exist multiple Term nodes for a single URI?

    terms_query =
     "MATCH (r:Term)
      RETURN r.uri, r.name, r.type
      ORDER BY r.uri
      LIMIT #{@limit}"

    terms_keys = ["uri", "name", "type"]
    terms_result = TraitBank.query(terms_query)

    spew_csv(terms_result, terms_keys, "terms.csv")

  end

  # Utility
  def spew_csv(start, keys, fname)
    FileUtils.mkdir_p @csvdir
    path = File.join(@csvdir, fname)
    csv = CSV.open(path, "wb")
    STDERR.puts "writing #{start["data"].length} csv records to #{path}"
    csv << keys
    start["data"].each do |row|
      csv << row
    end
    csv.close
    path
  end

end

# TESTING
# sample_clade = 7662  # carnivora
# TraitBank::TraitsDumper.dump_clade(sample_clade,
#                                  "sample-dumps/#{sample_clade}-short-csv",
#                                  10)

# REAL THING
# TraitBank::TraitsDumper.dump_clade(sample_clade,
#   "sample-dumps/#{sample_clade}-csv", 200000)
