# ID=7662 CHUNK=20000 time bundle exec rake dump_traits:dump

# ID=7674 CHUNK=20000 TOKEN=`cat ../api.token` ZIP=felidae.zip ruby -r ./lib/traits_dumper.rb -e TraitsDumper.main
# (7674 is Felidae)

# Generate CSV files expressing trait information for a single taxon
# recursively.

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
    dest = ENV['ZIP'] || "traits_dump.zip"   # where to put the final .zip file
    new(clade,                 # clade
        nil, # where to put intermediate csv files
        chunksize,                 # chunk size (for LIMIT and SKIP clauses)
        Proc.new {|cql| query_via_http(server, token, cql)}).dump_traits(dest)
  end

  # This method is suitable for use from a rake command.
  # The query_fn might use, say, neography, instead of an HTTP client.
  def self.dump_clade(clade_page_id, dest, csvdir, chunksize, query_fn)
    new(clade_page_id, csvdir, chunksize, query_fn).dump_traits(dest)
  end

  def initialize(clade_page_id, csvdir, chunksize, query_fn)
    # If clade_page_id is nil, that means do not filter by clade
    @clade = nil
    @clade = Integer(clade_page_id) if clade_page_id
    @csvdir = csvdir
    @chunksize = Integer(chunksize) if chunksize
    unless @csvdir
      prefix = "traitbank_#{DateTime.now.strftime("%Y%m")}"
      prefix = "#{prefix}_#{@clade}" if @clade
      prefix = "#{prefix}_chunked_#{chunksize}" if @chunksize
      @csvdir = "/tmp/#{prefix}_csv_temp"
    end
    @query_fn = query_fn
  end

  # dest is name of zip file to be written
  def dump_traits(dest)
    write_zip [emit_terms,
               emit_pages,
               emit_traits,
               emit_metadatas], 
              dest
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
    if /\A[\p{Alnum}:#_\/\.-]*\Z/.match(uri)
      false
    else
      STDERR.puts "scary URI: '#{uri}'"
      true
    end
  end

  #---- Query: Traits (trait records)

  def emit_traits
    filename = "traits.csv"
    path = File.join(@csvdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
      return
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
    for i in 0..predicates.length do
      predicate = predicates[i]
      next if is_attack?(predicate)
      STDERR.puts "#{i} #{predicate}" if i % 25 == 0
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
      ppath = supervise_query(traits_query, traits_keys, "traits_#{i}.csv")
      files.push(ppath) if ppath
    end
    assemble_chunks(files, path)
  end

  # Filtering by term type seems to be only an optimization, and
  # it's looking wrong to me.
  # What about the other types - association and value ?

  def list_trait_predicates
    predicates_query =
     'MATCH (term:Term {type: "measurement"})
      RETURN term.uri
      LIMIT 10000'
    run_query(predicates_query)["data"].map{|row| row[0]}
  end

  #---- Query: Metadatas
  # Structurally similar to traits.  I'm duplicating code because Ruby
  # style does not encourage procedural abstraction.

  def emit_metadatas
    filename = "metadata.csv"
    path = File.join(@csvdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
      return
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
      ppath = supervise_query(metadata_query, metadata_keys, "metadata_#{i}.csv")
      files.push(ppath) if ppath
    end
    assemble_chunks(files, path)
  end

  def list_metadata_predicates
    predicates_query =
     'MATCH (term:Term {type: "metadata"})
      RETURN term.uri
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

  # filename (where to put the .csv file) is interpreted relative to @csvdir
  # return value is full pathname to csv file, or nil if no results

  def supervise_query(query, columns, filename)
    path = File.join(@csvdir, filename)
    if File.exist?(path)
      #STDERR.puts "reusing previously created #{path}"
    else
      parts, count = get_query_chunks(query, columns, path)
      assemble_chunks(parts, path)
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

  def get_query_chunks(query, columns, path)

    # Create a directory path.parts to hold the parts
    parts_dir = path + ".parts"

    if @chunksize
      limit = "#{@chunksize}"
    else
      limit = "10000000"
    end

    parts = []
    skip = 0
    while true
      # Fetch it in parts
      part = File.join(parts_dir, "#{skip}.csv")
      if File.exist?(part)
        #STDERR.puts "reusing previously created #{part}"
        parts.push(part)
        # TBD: we should increase skip by the actual number of
        # records in the file.
        skip += @chunksize if @chunksize
      else
        result = run_query(query + " SKIP #{skip} LIMIT #{limit}")
        # A null result means that there was some kind of error, which
        # has already been reported.  (because I don't want to learn
        # ruby exception handling!)
        got = result["data"].length
        if result and got > 0
          emit_csv(result, columns, part)
          parts.push(part)
        end
        skip += got
        break if @chunksize and got < @chunksize
      end
      break unless @chunksize
    end
    [parts, skip]
  end

  # Combine the parts files (for a single table) into a single master .csv file
  # Returns path.  N.b. the CSV file might be empty.

  def assemble_chunks(parts, path)
    # Concatenate all the parts together
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
    end
    path
  end

  # Run a single CQL query using method provided

  def run_query(cql)
    @query_fn.call(cql)
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
      STDERR.puts "failed to write #{path}; result = #{start}"
      return nil
    end

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
# TraitsDumper.dump_clade(sample_clade,
#                         "sample-dumps/#{sample_clade}-short-csv",
#                         10)

# REAL THING
# TraitsDumper.dump_clade(sample_clade,
#   "sample-dumps/#{sample_clade}-csv", 200000)
