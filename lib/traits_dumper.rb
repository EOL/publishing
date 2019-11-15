# Generate a ZIP file containing a dump of the traits graphdb.
# The ZIP contains four CSV files:
#
#   traits.csv   - one row per Trait node
#   metadata.csv - one row per Metadata node
#   pages.csv    - one row per Page node
#   terms.csv    - one row per Term node
#   inferred.csv - one row per inferred_trait relationship
#
# This script can run in at least two different modes:
#  1. as a rake command (see lib/tasks/dump_traits.rake).  The 
#     graphdb is accessed directly, using neography.
#  2. directly from the shell, outside the rails / rake context.
#     The graphdb is accessed using the web API (over HTTP).
# The second mode is convenient because you can run it on machines
# where rails isn't installed.
#
# Parameters:
#   page id (ID) - if provided, the trait and metadata records are
#      restricted to those for taxa descending from the specified 
#      taxon.
#   chunk size (CHUNK) - number of rows to fetch per query.  20000
#      seems to be an OK value for this.
#   tempdir (TEMP) - where to put intermediate files for construction 
#      of the zip file.
#   destination (ZIP) - where to put the zip file.  Default is
#      a name that includes the ID and the month it was created.
#
# Parameters for API mode only:
#   server (SERVER) - base URL for the server to contact.  Should
#      end with a /.  Default https://eol.org/.
#   token (TOKEN) - authentication token for web API
#
# If the script is interrupted, it can be run again and it will use
# files created on a previous run, if the previous run was in the same
# calendar month.  This is a time saving measure.

# E.g. get traits for Felidae (7674):
#
# Run it directly from the shell
# ID=7674 CHUNK=20000 TOKEN=`cat api.token` ZIP=felidae.zip ruby -r ./lib/traits_dumper.rb -e TraitsDumper.main
#
# Run it as a 'rake' task
# ID=7674 CHUNK=20000 time bundle exec rake dump_traits:dump

# Thanks to Bill Tozier for code review; but he is not to be held
# responsible for anything you see here.

require 'csv'
require 'fileutils'
require 'zip'

# These are required if we want to be an HTTP client:
require 'net/http'
require 'json'
require 'cgi'

# An instance of the TraitsDumper class is sort of like a 'session'
# for producing a ZIP file.  Its state of all the parameters needed to
# harvest and write the required information.  The actual state for
# the session, however, resides in files in the file system.

class TraitsDumper
  # This method is suitable for invocation from the shell via
  #  ruby -r "./lib/traits_dumper.rb" -e "TraitsDumper.main"
  def self.main
    server = ENV['SERVER'] || "https://eol.org/"
    token = ENV['TOKEN'] || STDERR.puts("** No TOKEN provided")
    query_fn = Proc.new {|cql| query_via_http(server, token, cql)}

    clade = ENV['ID']           # possibly nil
    tempdir = ENV['TEMP']      # temp dir = where to put intermediate csv files
    chunksize = ENV['CHUNK']    # possibly nil
    dest = ENV['ZIP']
    new(clade, tempdir, chunksize, query_fn).dump_traits(dest)
  end

  # This method is suitable for use from a rake command.

  def self.dump_clade(clade_page_id, tempdir, chunksize, query_fn, dest)
    new(clade_page_id, tempdir, chunksize, query_fn).dump_traits(dest)
  end

  # Store parameters in instance so they don't have to be passed
  # around everywhere.
  # The query_fn takes a CQL query as input, executes it, and returns
  # a result set.  The result set is returned in the idiosyncratic
  # form delivered by neo4j.  The implementation of the query_fn might
  # use neography, or the EOL web API, or any other method for
  # executing CQL queries.

  def initialize(clade_page_id, tempdir, chunksize, query_fn)
    @clade = (clade_page_id ? Integer(clade_page_id) : nil)
    @tempdir = tempdir || File.join("/tmp", default_basename(@clade))
    @chunksize = Integer(chunksize) if chunksize
    # If clade_page_id is nil, that means do not filter by clade
    @query_fn = query_fn
  end

  # dest is name of zip file to be written, or nil for default
  def dump_traits(dest)
    paths = [emit_inferred,
             emit_terms,
             emit_pages,
             emit_traits,
             emit_metadatas]
    if not paths.include?(nil)
      dest ||= (default_basename(@clade) + ".zip")
      write_zip(paths, dest) 
    end
  end

  # Mostly-unique tag based on current month and clade id
  def default_basename(id)
    month = DateTime.now.strftime("%Y%m")
    tag = id || "all"
    "traits_#{tag}_#{month}"
  end

  # Write a zip file containing a specified set of files.
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

  # Return query fragment for lineage (clade, page, ID) restriction,
  # if there is one.
  def transitive_closure_part
    if @clade
      ", (page)-[:parent*]->(clade:Page {page_id: #{@clade}})"
    else
      ""
    end
  end

  # All of the following emit_ methods return the path to the
  # generated file, or nil if any query failed (e.g. timed out)

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
    # returns nil on failure (e.g. timeout)
  end

  #---- Query: Pages (taxa)
  # Ray Ma has pointed out that the traits dump contains page ids
  # that are not in this set, e.g. for interaction traits.

  def emit_pages
    pages_query =
     "MATCH (page:Page) #{transitive_closure_part}
      WHERE page.canonical IS NOT NULL
      OPTIONAL MATCH (page)-[:parent]->(parent:Page)
      RETURN page.page_id, parent.page_id, page.canonical"
    pages_keys = ["page_id", "parent_id", "canonical"] #fragile
    supervise_query(pages_query, pages_keys, "pages.csv")
    # returns nil on failure (e.g. timeout)
  end

  #---- Query: Traits (trait records)

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
    fails = []
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
      # ppath is nil on failure (e.g. timeout)
      ppath ? files.push(ppath) : fails.push(ppath)
    end
    if fails.empty?
      assemble_chunks(files, path)
    else
      STDERR.puts "** Deferred due to exception(s): traits.csv"
      nil
    end
  end

  # Filtering by term type seems to be only an optimization, and
  # it's looking wrong to me.
  # What about the other types - association and value ?

  # term.type can be: measurement, association, value, metadata

  # MATCH (pred:Term) WHERE (:Trait)-[:predicate]->(pred) RETURN pred.uri LIMIT 20

  def list_trait_predicates
    predicates_query =
      'MATCH (pred:Term)
      WHERE (pred)<-[:predicate]-(:Trait)
      RETURN DISTINCT pred.uri
      LIMIT 10000'
    run_query(predicates_query)["data"].map{|row| row[0]}
  end

  # Prevent injection attacks (quote marks in URIs and so on)
  def is_attack?(uri)
    if /\A[\p{Alnum}:#_=?#& \/\.-]*\Z/.match(uri)
      false
    else
      STDERR.puts "** scary URI: '#{uri}'"
      true
    end
  end

  #---- Query: Metadatas
  # Structurally similar to traits.  I'm duplicating code because Ruby
  # style does not encourage procedural abstraction (or at least, I
  # don't know how one properly share code here, in idiomatic Ruby).

  def emit_metadatas
    filename = "metadata.csv"
    path = File.join(@tempdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
      return path
    end
    metadata_keys = ["eol_pk", "trait_eol_pk", "predicate", "value_uri",
                     "measurement", "units_uri", "literal"]
    predicates = list_metadata_predicates
    STDERR.puts "#{predicates.length} metadata predicate URIs"
    files = []
    fails = []
    for i in 0..predicates.length do
      predicate = predicates[i]
      next if is_attack?(predicate)
      STDERR.puts "#{i} #{predicate}" if i % 25 == 0
      metadata_query = 
        "MATCH (m:MetaData)<-[:metadata]-(t:Trait),
              (t)<-[:trait]-(page:Page)
              #{transitive_closure_part}
        WHERE page.canonical IS NOT NULL
        MATCH (m)-[:predicate]->(predicate:Term),
              (t)-[:predicate]->(metadata_predicate:Term {uri: '#{predicate}'})
        OPTIONAL MATCH (m)-[:object_term]->(obj:Term)
        OPTIONAL MATCH (m)-[:units_term]->(units:Term)
        RETURN m.eol_pk, t.eol_pk, predicate.uri, obj.uri, m.measurement, units.uri, m.literal"
      ppath = supervise_query(metadata_query, metadata_keys, "metadata.csv.predicates/#{i}.csv")
      # ppath is nil on failure (e.g. timeout)
      ppath ? files.push(ppath) : fails.push(ppath)
    end
    if fails.empty?
      assemble_chunks(files, path)
    else
      STDERR.puts "** Deferred due to exception(s): metadata.csv"
      nil
    end
  end

  # Returns list (array) of URIs

  def list_metadata_predicates
    predicates_query =
     'MATCH (pred:Term)
      WHERE (pred)<-[:predicate]-(:MetaData)
      RETURN DISTINCT pred.uri
      LIMIT 10000'
    run_query(predicates_query)["data"].map{|row| row[0]}
  end

  def emit_inferred
    filename = "inferred.csv"
    path = File.join(@tempdir, filename)
    if File.exist?(path)
      STDERR.puts "reusing previously created #{path}"
      return path
    end
    inferred_keys = ["page_id", "inferred_trait"]
    inferred_query = 
       "MATCH (page:Page)-[:inferred_trait]->(trait:Trait)
        RETURN page.page_id AS page_id, trait.eol_pk AS trait"
    supervise_query(inferred_query, inferred_keys, filename)
  end

  # -----

  # supervise_query: generate a set of 'chunks', then put them
  # together into a single .csv file.

  # A chunk (or 'part,' I use these words interchangeably here) is
  # the result set of a single cypher query.  The queries are in a
  # single supervise_query call are all the same, except for the value
  # of the SKIP parameter.

  # The reason for this is that the result sets for some queries are
  # too big to capture with a single query, due to timeouts or other
  # problems.

  # Each chunk is placed in its own file.  If a chunk file already
  # exists the query is not repeated - the results from the previous
  # run are used directly without verification.

  # filename (where to put the .csv file) is interpreted relative to
  # @tempdir.  The return value is full pathname to csv file (which is
  # created even if empty), or nil if there was any kind of failure.

  def supervise_query(query, columns, filename)
    path = File.join(@tempdir, filename)
    if File.exist?(path)
      #STDERR.puts "reusing previously created #{path}"
      path
    else
      # Create a directory path.parts to hold the parts
      parts_dir = path + ".parts"
      begin
        parts, count = get_query_chunks(query, columns, parts_dir)
        # This always writes a .csv file to path, even if it's empty.
        assemble_chunks(parts, path)
        if Dir.exist?(parts_dir) && Dir.entries(parts_dir).length <= 2 # . and ..
          FileUtils.rmdir parts_dir
        end
        if count > 0
          STDERR.puts("#{File.basename(path)}: #{parts.length} parts, #{count} records")
        end
        path
      rescue => e
        STDERR.puts "** Failed to generate #{path}"
        STDERR.puts "** Exception: #{e}"
        nil
      end
    end
  end

  # Ensure that all the parts files for a table exist, using Neo4j to
  # obtain them as needed.
  # Returns a list of paths (file names for the parts) and a count of
  # the total number of rows (not always accurate).
  # A file will be created for every successful query, but the pathname
  # is only included in the returned list if it contains at least one row.

  def get_query_chunks(query, columns, parts_dir)
    limit = (@chunksize ? "#{@chunksize}" : "10000000")
    parts = []
    skip = 0

    # Keep doing queries until no more results are returned, or until
    # something goes wrong
    while true
      # Fetch it in parts
      basename = (@chunksize ? "#{skip}_#{@chunksize}" : "#{skip}")
      part_path = File.join(parts_dir, "#{basename}.csv")
      if File.exist?(part_path)
        if File.size(part_path) > 0
          parts.push(part_path)
        end
        # Ideally, we should increase skip by the actual number of
        # records in the file.
        skip += @chunksize if @chunksize
      else
        result = run_query(query + " SKIP #{skip} LIMIT #{limit}")
        got = result["data"].length
        if result
          # The skip == 0 test is a kludge that fixes a bug where the
          # header row was being omitted in some cases
          if got > 0 || skip == 0
            emit_csv(result, columns, part_path)
            parts.push(part_path)
          else
            FileUtils.mkdir_p File.dirname(part_path)
            FileUtils.touch(part_path)
          end
        end
        skip += got
        break if @chunksize && got < @chunksize
      end
      break unless @chunksize
    end
    [parts, skip]
  end

  # Combine the parts files (for a single table) into a single master
  # .csv file which is stored at path.
  # Always returns path, where a file (perhaps empty) will be found.

  def assemble_chunks(parts, path)
    # Concatenate all the parts together
    FileUtils.mkdir_p File.dirname(path)
    if parts.size == 0
      FileUtils.touch(path)
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

  # Run a single CQL query using the method provided (could be
  # neography, HTTP, ...)

  def run_query(cql)
    json = @query_fn.call(cql)
    if json && json["data"].length > 100
      # Throttle load on server
      sleep(1)
    end
    json
  end

  # A particular query method for doing queries using the EOL v3 API over HTTP

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
    if start["columns"] == nil or start["data"] == nil
      STDERR.puts "** failed to write #{path}; result = #{start}"
      return nil
    end
    temp = path + ".new"
    FileUtils.mkdir_p File.dirname(temp)
    csv = CSV.open(temp, "wb")
    csv << keys
    count = start["data"].length
    if count > 0
      STDERR.puts "writing #{count} csv records to #{temp}"
      start["data"].each do |row|
        csv << row
      end
    end
    csv.close
    FileUtils.mv temp, path
    path
  end

end
