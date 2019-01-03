# Generate CSV files expressing trait information for a single taxon
# recursively.

=begin
MATCH (term:Term)
 WHERE term.type = "measurement"
 OPTIONAL MATCH (term)-[:parent_term]->(parent:Term) 
 WHERE parent.uri IS NULL
 RETURN term.uri, term.name
 LIMIT 1000
=end

require 'csv'
require 'fileutils'

class TraitBank::TraitsDumper
  def self.dump_clade(clade_page_id, dest, csvdir, chunksize)
    new(clade_page_id, dest, csvdir, chunksize).doit
  end
  def initialize(clade_page_id, dest, csvdir, chunksize)
    # If clade_page_id is nil, that means do not filter by clade
    @clade = nil
    @clade = Integer(clade_page_id) if clade_page_id
    @dest = dest
    @csvdir = csvdir
    @chunksize = Integer(chunksize) if chunksize
  end
  def doit
    write_zip [emit_pages,
               emit_traits,
               emit_metadatas,
               emit_terms]
  end

  # There is probably a way to do this without creating the temporary
  # files at all.
  def write_zip(paths)
    File.delete(@dest) if File.exists?(@dest)
    Zip::File.open(@dest, Zip::File::CREATE) do |zipfile|
      directory = "trait_bank"
      zipfile.mkdir(directory)
      paths.each do |path|
        if path
          name = File.basename(path)
          STDERR.puts "storing #{name} into zip file"
          zipfile.add(File.join(directory, name), path)
        end
      end
      # Put it on its own line for easier cut/paste
      STDERR.puts @dest
    end
  end

  # Return query fragment for lineage restriction, if there is one
  def transitive_closure_part
    if @clade
      ", (page)-[:parent*]->(clade:Page {page_id: #{@clade}})"
    else
      ""
    end
  end

  #---- Query #3: Pages

  def emit_pages
    pages_query =
     "MATCH (page:Page) #{transitive_closure_part}
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (page)-[:parent]->(parent:Page)
      RETURN page.page_id, parent.page_id, page.canonical"
    pages_keys = ["page_id", "parent_id", "canonical"] #fragile
    supervise_query(pages_query, pages_keys, "pages.csv")
  end

  #---- Query #2: Traits

  def emit_traits

    traits_query =
     "MATCH (t:Trait)<-[:trait]-(page:Page)
            #{transitive_closure_part}
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
             t.literal"

    # Matching the keys used in the tarball if possible (even when inconsistent)
    # E.g. should "predicate" be "predicate_uri" ?

    traits_keys = ["eol_pk", "page_id", "resource_pk", "resource_id",
                   "source", "scientific_name", "predicate",
                   "object_page_id", "value_uri",
                   "normal_measurement", "normal_units_uri", "normal_units",
                   "measurement", "units_uri", "units",
                   "literal"]

    supervise_query(traits_query, traits_keys, "traits.csv")
  end

  #---- Query #1: Metadatas

  def emit_metadatas

    metadata_query = 
     "MATCH (m:MetaData)<-[:metadata]-(t:Trait),
            (t)<-[:trait]-(page:Page)
            #{transitive_closure_part}
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (m)-[:predicate]->(predicate:Term)
      OPTIONAL MATCH (m)-[:object_term]->(obj:Term)
      OPTIONAL MATCH (m)-[:units_term]->(units:Term)
      RETURN m.eol_pk, t.eol_pk, predicate.uri, obj.uri, m.measurement, units.uri, m.literal"

    metadata_keys = ["eol_pk", "trait_eol_pk", "predicate", "value_uri",
                     "measurement", "units_uri", "literal"]
    supervise_query(metadata_query, metadata_keys, "metadata.csv")
  end

  #---- Query #0: Terms

  def emit_terms

    # Many Term nodes have 'uri' properties that are not URIs.  Would it 
    # be useful to filter those out?  It's about 2% of the nodes.

    # I'm not sure where there exist multiple Term nodes for a single URI?

    terms_query =
     "MATCH (r:Term)
      OPTIONAL MATCH (r)-[:parent_term]->(parent:Term)
      RETURN r.uri, r.name, r.type, parent.uri
      ORDER BY r.uri"
    terms_keys = ["uri", "name", "type", "parent_uri"]
    supervise_query(terms_query, terms_keys, "terms.csv")
  end

  # -----

  # filename is relative to @csvdir

  def supervise_query(query, columns, filename)
    path = File.join(@csvdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
    else
      # Create a directory filename.parts to hold the parts
      parts_dir = path + ".parts"

      if @chunksize
        limit_phrase = "LIMIT #{@chunksize}"
      else
        limit_phrase = ""
      end

      parts = []
      skip = 0
      while true
        # Fetch it in parts
        part = File.join(parts_dir, "#{skip}.csv")
        if File.exist?(part)
          STDERR.puts "reusing previously created #{part}"
        else
          result = TraitBank.query(query + " SKIP #{skip} #{limit_phrase}")
          if result["data"].length > 0
            emit_csv(result, columns, part)
            parts.push(part)
          end
          break if @chunksize and result["data"].length < @chunksize
        end
        break unless @chunksize
        skip += @chunksize
      end

      # Concatenate all the parts together
      if parts.size == 0
        nil
      elsif parts.size == 1
        FileUtils.mv parts[0], path
        path
      else
        temp = path + ".new"
        STDERR.puts "creating #{temp}"
        # was: system "cat #{parts_dir}/*.csv >#{temp}"
        more = parts.drop(1).join(' ')
        command = "(cat #{parts[0]}; tail +2 -q #{more}) >#{temp}"
        STDERR.puts(command)
        system command
        FileUtils.mv temp, path
        path
      end
    end
  end

  # Utility
  def emit_csv(start, keys, path)
    FileUtils.mkdir_p File.dirname(path)
    temp = path + ".new"
    csv = CSV.open(temp, "wb")
    STDERR.puts "writing #{start["data"].length} csv records to #{temp}"
    csv << keys
    start["data"].each do |row|
      csv << row
    end
    csv.close
    FileUtils.mv temp, path
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
