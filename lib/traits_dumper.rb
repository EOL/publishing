# Generate a ZIP file containing trait and trait metadata records.
# The ZIP contains four CSV files:
#
#   traits.csv   - one row per Trait node
#   metadata.csv - one row per Metadata node
#   pages.csv    - one row per Page node
#   terms.csv    - one row per Term node
#
# If a page id is provided, the trait and metadata records are
# restricted to those for taxa descending from the specified taxon.
#
# This script can run independently of the rails / rake context,
# e.g. direct from the shell.

# E.g. get traits for Felidae (7674)

# Run it directly from the shell
# ID=7674 CHUNK=20000 TOKEN=`cat ../api.token` ZIP=felidae.zip ruby -r ./lib/traits_dumper.rb -e TraitsDumper.main

# Run it as a 'rake' task
# ID=7662 CHUNK=20000 time bundle exec rake dump_traits:dump

require 'csv'
require 'fileutils'
require 'zip'

# These are required if we want to be an HTTP client:
require 'net/http'
require 'json'
require 'cgi'

class TraitsDumper
  # This method is suitable for invocation from the shell via
  #  ruby -r "./lib/traits_dumper.rb" -e "TraitsDumper.main"
  def self.main
    clade = ENV['ID']           # possibly nil
    chunksize = ENV['CHUNK']    # possibly nil
    server = ENV['SERVER'] || "https://eol.org/"
    token = ENV['TOKEN'] || STDERR.puts("** No TOKEN provided")
    dest = ENV['ZIP']
    tempdir = ENV['TEMP']
    new(clade,      # clade or nil
        tempdir,    # temp dir = where to put intermediate csv files
        chunksize,                 # chunk size (for LIMIT and SKIP clauses)
        Proc.new {|cql| query_via_http(server, token, cql)}).dump_traits(dest)
  end

  # This method is suitable for use from a rake command.
  # The query_fn returns the query results in the idiosyncratic form
  # delivered by neo4j, or nil.  might use, say, neography, instead of
  # an HTTP client.

  def self.dump_clade(clade_page_id, dest, tempdir, chunksize, query_fn)
    new(clade_page_id, tempdir, chunksize, query_fn).dump_traits(dest)
  end

  def initialize(clade_page_id, tempdir, chunksize, query_fn)
    @chunksize = Integer(chunksize) if chunksize
    # If clade_page_id is nil, that means do not filter by clade
    @clade = nil
    @clade = Integer(clade_page_id) if clade_page_id
    @tempdir = tempdir || File.join("/tmp", default_basename(@clade))
    @query_fn = query_fn
  end

  # dest is name of zip file to be written
  def dump_traits(dest)
    paths = [emit_terms,
             emit_pages,
             emit_traits,
             emit_metadatas]
    dest ||= (default_basename(@clade) + ".zip")
    write_zip(paths, dest)
  end

  # Mostly-unique tag based on date and id
  def default_basename(id)
    month = DateTime.now.strftime("%Y%m")
    tag = id || "all"
    "traits_#{tag}_#{month}"
  end

  # There is probably a way to do this without creating the temporary
  # files at all.
  def write_zip(paths, dest)
    File.delete(dest) if File.exists?(dest)
    Zip::File.open(dest, Zip::File::CREATE) do |zipfile|
      directory = "trait_bank"
      zipfile.mkdir(directory)
      paths.each do |path|
        if path
          name = File.basename(path)
          STDERR.puts "storing #{name} into zip file"
          zipfile.add(File.join(directory, name), path)
        end
      end
      # Put file name on its own line for easier cut/paste
      STDERR.puts dest
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

  #---- Query: Terms

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

  #---- Query: Pages (taxa)

  def emit_pages
    pages_query =
     "MATCH (page:Page) #{transitive_closure_part}
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (page)-[:parent]->(parent:Page)
      RETURN page.page_id, parent.page_id, page.canonical"
    pages_keys = ["page_id", "parent_id", "canonical"] #fragile
    supervise_query(pages_query, pages_keys, "pages.csv")
  end

  # Prevent injection attacks
  def is_attack?(uri)
    if /\A[\p{Alnum}:#_=?#& \/\.-]*\Z/.match(uri)
      false
    else
      STDERR.puts "** scary URI: '#{uri}'"
      true
    end
  end

  #---- Query: Traits (trait records)
  # Returns path

  def emit_traits
    filename = "traits.csv"
    path = File.join(@tempdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
      return path
    end
    # Matching the keys used in the tarball if possible (even when inconsistent)
    # E.g. should "predicate" be "predicate_uri" ?
    traits_keys = ["eol_pk", "page_id", "resource_pk", "resource_id",
                   "source", "scientific_name", "predicate",
                   "object_page_id", "value_uri",
                   "normal_measurement", "normal_units_uri", "normal_units",
                   "measurement", "units_uri", "units",
                   "literal"]
    predicates = list_trait_predicates
    STDERR.puts "#{predicates.length} trait predicate URIs"
    files = []
    dir = "traits.csv.predicates"

    for i in 0..predicates.length do
      predicate = predicates[i]
      STDERR.puts "Predicate #{i} = #{predicate}" if i % 25 == 0
      next if is_attack?(predicate)
      traits_query =
       "MATCH (t:Trait)<-[:trait]-(page:Page)
              #{transitive_closure_part}
        WHERE page.canonical IS NOT NULL
        MATCH (t)-[:predicate]->(predicate:Term {uri: '#{predicate}'})
        OPTIONAL MATCH (t)-[:supplier]->(r:Resource)
        OPTIONAL MATCH (t)-[:object_term]->(obj:Term)
        OPTIONAL MATCH (t)-[:normal_units_term]->(normal_units:Term)
        OPTIONAL MATCH (t)-[:units_term]->(units:Term)
        RETURN t.eol_pk, page.page_id, r.resource_pk, r.resource_id,
               t.source, t.scientific_name, predicate.uri,
               t.object_page_id, obj.uri,
               t.normal_measurement, normal_units.uri, t.normal_units, 
               t.measurement, units.uri, t.units, 
               t.literal"
      # TEMPDIR/{traits,metadata}.csv.predicates/
      ppath = supervise_query(traits_query, traits_keys, "traits.csv.predicates/#{i}.csv")
      files.push(ppath) if ppath
    end
    assemble_chunks(files, path)
  end

  # Filtering by term type seems to be only an optimization, and
  # it's looking wrong to me.
  # What about the other types - association and value ?

  # term.type can be: measurement, association, value, metadata

  def list_trait_predicates
    predicates_query =
     'MATCH (term:Term)<-[:predicate]-(trait:Trait)
      RETURN DISTINCT term.uri
      LIMIT 10000'
    run_query(predicates_query)["data"].map{|row| row[0]}
  end

  #---- Query: Metadatas
  # Structurally similar to traits.  I'm duplicating code because Ruby
  # style does not encourage procedural abstraction.

  def emit_metadatas
    filename = "metadata.csv"
    path = File.join(@tempdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
      return path
    end
    metadata_keys = ["eol_pk", "trait_eol_pk", "predicate", "value_uri",
                     "measurement", "units_uri", "literal"]
    trait_predicates = list_trait_predicates
    STDERR.puts "#{trait_predicates.length} trait predicate URIs"
    files = []
    for i in 0..trait_predicates.length do
      trait_predicate = trait_predicates[i]
      next if is_attack?(trait_predicate)
      STDERR.puts "#{i} #{trait_predicate}" if i % 25 == 0
      metadata_query = 
       "MATCH (m:MetaData)<-[:metadata]-(t:Trait),
              (t)<-[:trait]-(page:Page)
              #{transitive_closure_part}
        WHERE page.canonical IS NOT NULL
        MATCH (m)-[:predicate]->(predicate:Term),
              (t)-[:predicate]->(trait_predicate:Term {uri: '#{trait_predicate}'})
        OPTIONAL MATCH (m)-[:object_term]->(obj:Term)
        OPTIONAL MATCH (m)-[:units_term]->(units:Term)
        RETURN m.eol_pk, t.eol_pk, predicate.uri, obj.uri, m.measurement, units.uri, m.literal"
      ppath = supervise_query(metadata_query, metadata_keys, "metadata.csv.predicates/#{i}.csv")
      files.push(ppath) if ppath
    end
    assemble_chunks(files, path)
  end

  # Returns list (array) of URIs

  def list_metadata_predicates
    predicates_query =
     'MATCH (term:Term)<-[:predicate]-(m:MetaData)
      RETURN DISTINCT term.uri
      LIMIT 10000'
    run_query(predicates_query)["data"].map{|row| row[0]}
  end

  # -----

  # supervise_query: generate parts, then put them together.

  # The purpose is to create a .csv file for a particular table (traits, 
  # pages, etc.).

  # The result sets are too big to capture with a single query, due to
  # timeouts or other problems, so the query is applied many times
  # to get "chunks" of results.

  # Each chunk is placed in a file.  If a chunk file already exists
  # the query is not repeated - the results from the previous run are
  # used directly without verification.

  # filename (where to put the .csv file) is interpreted relative to @tempdir.
  # Return value is full pathname to csv file (which is created even if empty).

  def supervise_query(query, columns, filename)
    path = File.join(@tempdir, filename)
    if File.exist?(path)
      #STDERR.puts "reusing previously created #{path}"
    else
      # Create a directory path.parts to hold the parts
      parts_dir = path + ".parts"
      parts, count = get_query_chunks(query, columns, parts_dir)
      # This always writes a .csv file to path, even if it's empty.
      assemble_chunks(parts, path)
      if Dir.exist?(parts_dir) && Dir.entries(parts_dir).length <= 2 # . and ..
        FileUtils.rmdir parts_dir
      end
      if count > 0
        STDERR.puts("#{File.basename(path)}: #{parts.length} parts, #{count} records")
      end
    end
    path
  end

  # Ensure that all the parts files for a table exist, using Neo4j to
  # obtain them as needed.
  # Returns a list of paths (file names for the parts) and a count of
  # the total number of records.
  # Every part will have at least one record.

  def get_query_chunks(query, columns, parts_dir)
    limit = (@chunksize ? "#{@chunksize}" : "10000000")
    parts = []
    skip = 0

    # Keep doing queries until no more results are returned
    while true
      # Fetch it in parts
      basename = (@chunksize ? "#{skip}_#{@chunksize}" : "#{skip}")
      part_path = File.join(parts_dir, "#{basename}.csv")
      if File.exist?(part_path)
        parts.push(part_path)
        # Ideally, we should increase skip by the actual number of
        # records in the file.
        skip += @chunksize if @chunksize
      else
        result = run_query(query + " SKIP #{skip} LIMIT #{limit}")
        # A null result means that there was some kind of error, which
        # has already been reported.  (because I don't want to learn
        # ruby exception handling!)
        got = result["data"].length
        if result && got > 0
          emit_csv(result, columns, part_path)
          parts.push(part_path)
        end
        skip += got
        break if @chunksize && got < @chunksize
      end
      break unless @chunksize
    end
    [parts, skip]
  end

  # Combine the parts files (for a single table) into a single master .csv file
  # which is stored at path.
  # Always returns path.

  def assemble_chunks(parts, path)
    # Concatenate all the parts together
    FileUtils.mkdir_p File.dirname(path)
    if parts.size == 0
      # THIS CAN BE DONE IN RUBY - just don't want to look up how right now
      system "touch #{path}"
    elsif parts.size == 1
      FileUtils.mv parts[0], path
    else
      temp = path + ".new"
      tails = parts.drop(1).map { |path| "tail +2 #{path}" }
      more = tails.join(';')
      command = "(cat #{parts[0]}; #{more}) >#{temp}"
      system command
      FileUtils.mv temp, path
      # We could delete the directory and all the files in it, but
      # instead let's leave it around for debugging (or something)
    end
    path
  end

  # Run a single CQL query using method provided

  def run_query(cql)
    json = @query_fn.call(cql)
    if json && json["data"].length > 100
      # Throttle load on server
      sleep(1)
    end
    json
  end

  # Method for doing queries using EOL v3 API via HTTP

  def self.query_via_http(server, token, cql)
    # Need to be a web client.
    # "The Ruby Toolbox lists no less than 25 HTTP clients."
    escaped = CGI::escape(cql)
    uri = URI("#{server}service/cypher?query=#{escaped}")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "JWT #{token}"
    use_ssl = uri.scheme.start_with?("https")
    response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => use_ssl) {|http|
      http.request(request)
    }
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)    # can return nil
    else
      STDERR.puts(response.body)
      nil
    end
  end

  # Utility - convert native cypher output form to CSV
  def emit_csv(start, keys, path)
    # Sanity check the result
    if start["columns"] == nil or start["data"] == nil or start["data"].length == 0
      STDERR.puts "** failed to write #{path}; result = #{start}"
      return nil
    end
    temp = path + ".new"
    FileUtils.mkdir_p File.dirname(temp)
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
# TraitsDumper.dump_clade(sample_clade,
#                         "sample-dumps/#{sample_clade}-short-csv",
#                         10)

# REAL THING
# TraitsDumper.dump_clade(sample_clade,
#   "sample-dumps/#{sample_clade}-csv", 200000)
