# 'Branch painting' utility.

# This script implements a suite of commands related to branch
# painting.
#
# . directives - lists all of a resource's branch painting directives
#      ('start' and 'stop' metadata nodes)
# . qc - run a series of quality control queries to identify problems
#      with the resource's directives
# . infer - determine a resource's inferred trait assertions (based on
#      directives), and write them to a file
# . merge - read inferred trait assertions from file (see `infer`) and
#      add them to the graphdb
# . count - count a resource's inferred trait assertions
# . clean - remove all of a resource's inferred trait assertions
#
# The choice of command, and any parameters, are communicated via
# shell variables.  Shell variables can be set using `export` or
# using the bash syntax "variable=value command".
#
# Shell variables:
# . COMMAND - a command, see list above
# . SERVER - the http server for an EOL web app instance, used for its
#      cypher service.  E.g. "https://eol.org/"
# . TOKEN - API token to be used with SERVER
# . RESOURCE - the resource id of the resource to be painted

# For example:
#
# export SERVER="http://127.0.0.1:3000/"
# export TOKEN=`cat ~/Sync/eol/admin.token`
#
# RESOURCE=640 COMMAND=qc ruby -r ./lib/painter.rb -e Painter.main

# Branch painting generates a lot of logging output.  If you have a
# local instance you might want to put 'config.log_level = :warn' in
# config/environments/development.rb to reduce noise emitted to
# console.

require 'csv'
require 'open3'

# These are required if we want to be an HTTP client:
require 'net/http'
require 'json'
require 'cgi'

require_relative 'paginator'

class Painter

  @silly_resource = 99999
  @silly_file = "directives.tsv"
  @page_origin = 500000000

  START_TERM = "https://eol.org/schema/terms/starts_at"
  STOP_TERM  = "https://eol.org/schema/terms/stops_at"
  SILLY_TERM = "http://example.org/numlegs"
  LIMIT = 1000000

  def self.main
    server = ENV['SERVER'] || "https://eol.org/"
    token = ENV['TOKEN'] || STDERR.puts("** No TOKEN provided")
    query_fn = Proc.new {|cql| query_via_http(server, token, cql)}
    painter = new(query_fn)

    command = ENV["COMMAND"]
    if ENV.key?("RESOURCE")
      resource = Integer(ENV["RESOURCE"])
    else
      resource = @silly_resource
    end

    # Command dispatch
    case command
    when "directives" then
      painter.show_directives(resource)
    when "qc" then
      painter.qc(resource)
    when "infer" then    # list the inferences to file
      painter.infer(resource)
    when "merge" then    # assert the inferences from file
      painter.merge(resource)
    when "paint" then    # assert the inferences directly
      painter.paint(resource)
    when "count" then    # remove the inferences
      painter.count(resource)
    when "clean" then    # remove the inferences
      painter.clean(resource)
    else
      painter.debug(command, resource, @page_origin)
    end
  end

  def initialize(query_fn)
    @query_fn = query_fn
    @paginator = Paginator.new(query_fn)
    @pagesize = 10000
  end

  # List all of a resource's start and stop directives
  # Use sort -k 1 -t , to mix them up

  def show_directives(resource)
    puts("trait,which,page_id,canonical")
    show_stxx_directives(resource, START_TERM, "Start")
    show_stxx_directives(resource, STOP_TERM, "Stop")
  end

  def show_stxx_directives(resource, uri, tag)
    r = run_query(
      "WITH '#{tag}' AS tag
         MATCH (r:Resource {resource_id: #{resource}})<-[:supplier]-
               (t:Trait)-[:metadata]->
               (m:MetaData)-[:predicate]->
               (:Term {uri: '#{uri}'}),
               (p:Page)-[:trait]->(t)
         WITH p, t, #{cast_page_id('m')} as point_id, tag
         MATCH (point:Page {page_id: point_id})
         OPTIONAL MATCH (point)-[:parent]->(parent:Page)
         RETURN t.resource_pk, tag, point_id, point.canonical, parent.page_id
         ORDER BY t.resource_pk, point_id
         LIMIT 10000")
    if r
      STDERR.puts("#{r["data"].size} #{tag} directives")
      r["data"].each do |trait, tag, id, canonical, parent_id|
        puts("#{trait},#{tag},#{id},#{canonical},#{parent_id}")
      end
    end
  end

  def cast_page_id(m)
    if true
      "toInteger(#{m}.measurement)"
    else
      "#{m}.object_page_id"
    end
  end

  # Remove all of a resource's inferred trait assertions

  def clean(resource)
    r = run_query("MATCH (:Resource {resource_id: #{resource}})<-[:supplier]-
                         (:Trait)<-[r:inferred_trait]-
                         (:Page)
                   DELETE r
                   RETURN COUNT(*)
                   LIMIT 10")
    if r
      STDERR.puts(r["data"][0])
    end
  end

  # Display count of a resource's inferred trait assertions

  def count(resource)
    r = run_query("MATCH (:Resource {resource_id: #{resource}})<-[:supplier]-
                         (:Trait)<-[r:inferred_trait]-
                         (:Page)
                   RETURN COUNT(*)
                   LIMIT 10")
    if r
      STDERR.puts(r["data"][0])
    end
  end

  # Quality control - for each trait, check its start and stop
  # directives to make sure their pages exist and are in the DH
  # (i.e. have parents), and every stop is under some start

  def qc(resource)
    qc_presence(resource, START_TERM, "start")
    qc_presence(resource, STOP_TERM, "stop")

    # Make sure every stop point is under some start point
    r = run_query("MATCH (r:Resource {resource_id: #{resource}})<-[:supplier]-
                         (t:Trait)-[:metadata]->
                         (m2:MetaData)-[:predicate]->
                         (:Term {uri: '#{STOP_TERM}'})
                   WITH t, #{cast_page_id('m2')} AS stop_id
                   MATCH (stop:Page {page_id: stop_id})
                   OPTIONAL MATCH 
                         (t)-[:metadata]->
                         (m1:MetaData)-[:predicate]->
                         (:Term {uri: '#{START_TERM}'})
                   WITH t, stop_id, #{cast_page_id('m1')} AS start_id
                   MATCH (start:Page {page_id: start_id})
                   OPTIONAL MATCH (stop)-[z:parent*1..]->(start)
                   WITH stop_id, stop, t
                   WHERE z IS NULL
                   RETURN stop_id, stop.canonical, t.eol_pk
                   ORDER BY stop.page_id, stop_id
                   LIMIT 1000")
    if r
      r["data"].each do |id, canonical, trait|
        STDERR.puts("Stop page #{id} = #{canonical} not under any start page for #{trait}")
      end
    end
  end

  def qc_presence(resource, term, which)
    r = run_query("MATCH (:Resource {resource_id: 635})<-[:supplier]-
                         (:Trait)-[:metadata]->
                         (m:MetaData)-[:predicate]->
                         (:Term {uri: '#{term}'})
                   WITH DISTINCT #{cast_page_id('m')} AS point_id
                   OPTIONAL MATCH (point:Page {page_id: point_id})
                   OPTIONAL MATCH (point)-[:parent]->(parent:Page)
                   WITH point_id, point, parent
                   WHERE parent IS NULL
                   RETURN point_id, point.page_id, point.canonical
                   ORDER BY point.page_id, point_id
                   LIMIT 1000")
    if r
      r["data"].each do |id, found, canonical|
        if found
          STDERR.puts("#{which} point #{id} = #{canonical} has no parent (is not in DH)")
        else
          STDERR.puts("Missing #{which} point #{id}")
        end
      end
    end
  end

  # Dry run - find all inferences that would be made by branch
  # painting, and put them in a file for review

  def infer(resource)
    base_dir = "infer-#{resource.to_s}"

    # Run the two queries
    (assert_path, retract_path) =
      paint_or_infer(resource,
                     "RETURN d.page_id AS page, t.eol_pk AS trait, d.canonical, t.measurement, o.name",
                     "RETURN d.page_id AS page, t.eol_pk AS trait",
                     base_dir, true)

    # We'll start by filling the inferences list with the assertions
    # (start point descendants), then remove the retractions

    inferences = {}
    duplicates = []
    CSV.foreach(assert_path, {encoding:'UTF-8'}) do |page_id, trait, name, value, ovalue|
      next if page_id == "page_id"    # gross
      if inferences.include?([page_id, trait])
        duplicates << [page_id, trait]
      else
        inferences[[page_id, trait]] = [name, value, ovalue]
      end
    end
    STDERR.puts("Found #{inferences.size} proper start-point descendants")
    if duplicates.size > 0
      STDERR.puts("Found #{duplicates.size} duplicate start-point descendants:")
      duplicates.each do |key|
        (page, trait) = key
        STDERR.puts("#{page},#{trait}")
      end
    end

    # Now retract the retractions (stopped inferences)
    if retract_path
      removed = 0
      CSV.foreach(retract_path, {encoding:'UTF-8'}) do |page_id, trait|
        next if page_id == "page_id"    # gross
        inferences.delete([page_id, trait])
        removed += 1
      end
      STDERR.puts("Removed #{removed} stop-point descendants")
    else
      STDERR.puts("No stop-point descendants to remove")
    end

    net_path = File.join(base_dir, "inferences.csv")

    # Write net inferences as single CSV (optional)
    STDERR.puts("Net: #{inferences.size} inferences")
    CSV.open(net_path, "wb:UTF-8") do |csv|
      STDERR.puts("Writing #{net_path}")
      csv << ["page_id", "name", "trait", "measurement", "object_name"]
      inferences.each do |key, info|
        (page_id, trait) = key
        (name, value, ovalue) = info
        csv << [page_id, name, trait, value, ovalue]
      end
    end

    # Write net inferences as a set of chunked CSV files (see merge)
    explode(inferences, net_path)

  end

  # Write a unitary inferences list as a sequence of chunked files

  def explode(inferences, net_path)
    a = inferences.to_a
    number_of_chunks = a.size / @pagesize + 1
    dir_path = net_path + ".chunks"
    FileUtils.mkdir_p dir_path
    (0...number_of_chunks).each do |chunk|
      n = chunk * @pagesize
      chunk_path = File.join(dir_path, "#{n}_#{@pagesize}.csv")
      CSV.open(chunk_path, "wb:UTF-8") do |csv|
        STDERR.puts("Writing #{chunk_path}")
        csv << ["page_id", "name", "trait", "measurement", "object_name"]
        a[n...n+@pagesize].each do |key, info|
          (page, trait) = key
          (name, value, ovalue) = info
          csv << [page, name, trait, value, ovalue]
        end
      end
    end
  end

  # Need to know:
  #  1. The way to refer to the server directory using scp
  #  2. The way to refer to the server directory using http

  def merge(resource)
    server_base_url = "http://varela.csail.mit.edu/~jar/tmp/"
    server_base_scp = "varela:public_html/tmp/"

    base_dir = "infer-#{resource.to_s}"
    net_path = File.join(base_dir, "inferences.csv")
    chunks_path = net_path + ".chunks"
    d = Dir.new(chunks_path)
    d.each do |name|
      next unless name.end_with? ".csv"
      long_name = "#{base_dir}=#{name}"
      chunk_path = File.join(chunks_path, name)    # local
      # don't bother creating a directory on the server, too lazy to figure out
      scp_target = "#{server_base_scp}#{long_name}"
      url = "#{server_base_url}#{long_name}"    #no need to escape
      # Need to move this file to some server so EOL can access it.
      STDERR.puts("Copying #{chunk_path} to #{scp_target}")
      stdout_string, status = Open3.capture2("rsync -p #{chunk_path} #{scp_target}")
      query = "LOAD CSV WITH HEADERS FROM '#{url}'
               AS row
               MATCH (page:Page {page_id: toInteger(row.page_id)})
               MATCH (trait:Trait {eol_pk: row.trait})
               MERGE (page)-[i:inferred_trait]->(trait)
               RETURN COUNT(i) 
               LIMIT 1"
      r = run_query(query)
      if r
        count = r["data"][0]
      else
        count = 0
      end
      STDERR.puts("Merged #{count} relations from #{url}")
    end
  end

  # Do branch painting
  # Probably a good idea to precede this with `rm -r paint-{resource}`
  # - At present this method doesn't work because paged deletion
  #   doesn't work.  Consider deleting this method.

  def paint(resource)
    base_dir = "paint-#{resource.to_s}"
    paint_or_infer(resource,
                   "MERGE (d)-[:inferred_trait]->(t)
                    RETURN d.page_id AS page_id, t.eol_pk AS trait",
                   "MATCH (d)-[i:inferred_trait]->(t)
                    DELETE i 
                    RETURN d.page_id AS page_id, t.eol_pk AS trait",
                   base_dir,
                   # Don't chunk the deletion!!!
                   false)
    # Now, at this point, we *could* read the counts out of the files,
    # but if we had wanted that information we could have said "infer"
    # instead of "paint".
  end

  # Run the two cypher commands (RETURN for "infer" operation; MERGE
  # and DELETE for "paint")

  def paint_or_infer(resource, merge, delete, base_dir, skipping)
    # Propagate traits from start point to descendants.  Filter by resource.
    # Currently assumes the painted trait has an object_term, but this
    # should be generalized to allow measurement as well
    query =
      "MATCH (:Resource {resource_id: #{resource}})<-[:supplier]-
                (t:Trait)-[:metadata]->
                (m:MetaData)-[:predicate]->
                (:Term {uri: '#{START_TERM}'})
          OPTIONAL MATCH (t)-[:object_term]->(o:Term)
          WITH t, #{cast_page_id('m')} as start_id, o
          MATCH (:Page {page_id: start_id})<-[:parent*1..]-(d:Page)
    #{merge}"
    STDERR.puts(query)
    assert_path = 
      run_chunked_query(query, @pagesize, File.join(base_dir, "assert.csv"))
    return unless assert_path

    # Erase inferred traits from stop point to descendants.
    query = 
      "MATCH (:Resource {resource_id: #{resource}})<-[:supplier]-
                (t:Trait)-[:metadata]->
                (m:MetaData)-[:predicate]->
                (:Term {uri: '#{STOP_TERM}'})
          WITH t, #{cast_page_id('m')} as stop_id
          MATCH (stop:Page {page_id: stop_id})
          WITH stop, t
          MATCH (stop)<-[:parent*0..]-(d:Page)
    #{delete}"
    STDERR.puts(query)
    retract_path =
      run_chunked_query(query, @pagesize, File.join(base_dir, "retract.csv"), skipping)
    [assert_path, retract_path]
  end

  # For long-running queries (writes to path).  Return value if path
  # on success, nil on failure.

  def run_chunked_query(cql, pagesize, path, skipping=true)
    Paginator.new(@query_fn).supervise_query(cql, nil, pagesize, path, skipping)
  end

  # For small / debugging queries

  def run_query(cql)
    # TraitBank::query(cql)
    json = @query_fn.call(cql)
    if json && json["data"].length > 100
      # Throttle load on server
      sleep(1)
    end
    json
  end

  # A particular query method for doing queries using the EOL v3 API over HTTP
  # CODE COPIED FROM traits_dumper.rb - we might want to factor this out...

  def self.query_via_http(server, token, cql)
    # Need to be a web client.
    # "The Ruby Toolbox lists no less than 25 HTTP clients."
    escaped = CGI::escape(cql)
    uri = URI("#{server}service/cypher?query=#{escaped}")
    use_ssl = (uri.scheme == "https")
    Net::HTTP.start(uri.host, uri.port, :use_ssl => use_ssl) do |http|
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "JWT #{token}"
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)    # can return nil
      else
        STDERR.puts("** HTTP response: #{response.code} #{response.message}")
        if response.code >= '300' && response.code < '400'
          STDERR.puts("** Location: #{response["Location"]}")
        end
        # Ideally we'd print only those lines that have useful 
        # information (error message and backtrace).
        # /home/jar/g/eol_website/lib/painter.rb:297:in `block in merge': 
        #     undefined method `[]' for nil:NilClass (NoMethodError)
        #   from /home/jar/g/eol_website/lib/painter.rb:280:in `each'
        STDERR.puts(cql)
        STDERR.puts(response.body)
        nil
      end
    end
  end

  # ------------------------------------------------------------------
  # Everything from here down is for debugging.

  # A complete smoke test for branch painting would look like this:
  #   init     - create silly hierarchy and traits
  #   test     - add painting directives
  #   infer    - do inference and write to files
  #   merge    - apply inference (in files) to pages
  #   ?        - check that correct inference(s) got made
  #   flush    - remove junk created by this test

  def debug(command, resource, page_origin)
    case command
    when "init" then
      populate(resource, page_origin)
    when "test" then            # Add some directives
      test(resource, page_origin)
    when "load" then
      filename = get_directives_filename
      load_directives(filename, resource)
    when "show" then
      show(resource)
    when "flush" then
      flush(resource)
    else
      STDERR.puts("Unrecognized command: #{command}")
    end
  end

  def get_directives_filename
    if ENV.key?("DIRECTIVES")
      ENV["DIRECTIVES"]
    else
      @silly_file
    end
  end

  # Load directives from TSV file... this was just for testing

  def load_directives(filename, resource)
    # Columns: page, stop-point-for, start-point-for, comment
    process_stream(CSV.open(filename, "r",
                            { :col_sep => "\t",
                              :headers => true,
                              :header_converters => :symbol }),
                   resource)
  end

  def process_stream(z, resource)
    # page is a page_id, stop and start are trait resource_pk's
    # TBD: Check headers to make sure they contain 'page' 'stop' and 'start'
    # z.shift  ???
    # error unless 'page' in z.headers 
    # error unless 'stop' in z.headers 
    # error unless 'start' in z.headers 
    z.each do |row|
      page_id = Integer(row[:page])
      if row.key?(:stop)
        add_directive(page_id, row[:stop], STOP_TERM, :stop, resource)
      end
      if row.key?(:start)
        add_directive(page_id, row[:start], START_TERM, :start, resource)
      end
    end
  end

  # Utility for testing purposes only:
  # Create a stop or start pseudo-trait on a page, indicating that
  # painting of the trait indicated by trait_id should stop or
  # start at that page.
  # Pred (a URI) indicates whether it's a stop or start.
  # Setting both object_page_id and measurement during representation 
  # transition.

  def add_directive(page_id, trait_id, pred, tag, resource)
    # Pseudo-trait id unique only within resource
    directive_eol_pk = "R#{resource}-BP#{tag}.#{page_id}.#{trait_id}"
    r = run_query(
      "MATCH (t:Trait {resource_pk: '#{trait_id}'})-[:supplier]->
             (r:Resource {resource_id: #{resource}})
       MERGE (pred:Term {uri: '#{pred}'})
       MERGE (m:MetaData {eol_pk: '#{directive_eol_pk}',
                          object_page_id: #{page_id},
                          measurement: '#{page_id}'})
       MERGE (m)-[:predicate]->(pred)
       MERGE (t)-[:metadata]->(m)
       RETURN m.eol_pk
       LIMIT 10")
    if r["data"].length == 0
      STDERR.puts("Failed to add #{tag}(#{page_id},#{trait_id})")
    else
      STDERR.puts("Added #{tag}(#{page_id},#{trait_id})")
    end
  end

  # Load directives specified inline (not from a file)
  # Assumes existence of a Trait node in the resource with 
  # resource_pk = 'tt_2'

  def test(resource, page_origin)
    process_stream([{:page => page_origin+2, :start => 'tt_2'},
                    {:page => page_origin+4, :stop => 'tt_2'}],
                   resource)
    show(resource)
  end

  # *** Debugging utility ***
  def show(resource)
    puts "State:"
    # List our private taxa
    r = run_query(
     "MATCH (p:Page {testing: 'yes'})
      OPTIONAL MATCH (p)-[:parent]->(q:Page)
      RETURN p.page_id, q.page_id
      LIMIT 100")
    r["data"].map{|row| puts "Page: #{row}\n"}

    # Show the resource
    r = run_query(
      "MATCH (r:Resource {resource_id: #{resource}})
       RETURN r.resource_id
       LIMIT 100")
    r["data"].map{|row| puts "Resource: #{row}\n"}

    # Show all traits for test resource, with their pages
    r = run_query(
      "MATCH (t:Trait)-[:supplier]->
             (:Resource {resource_id: #{resource}}),
             (t)-[:predicate]->(pred:Term)
       OPTIONAL MATCH (p:Page)-[:trait]->(t)
       RETURN t.eol_pk, t.resource_pk, pred.name, p.page_id
       LIMIT 100")
    r["data"].map{|row| puts "Trait: #{row}\n"}

    # Show all MetaData nodes
    r = run_query(
        "MATCH (m:MetaData)<-[:metadata]-
               (t:Trait)-[:supplier]->
               (r:Resource {resource_id: #{resource}}),
               (m)-[:predicate]->(pred:Term)
         RETURN t.resource_pk, pred.uri, #{cast_page_id('m')}
         LIMIT 100")
    r["data"].map{|row| puts "Metadatum: #{row}\n"}

    # Show all inferred trait assertions
    r = run_query(
     "MATCH (p:Page)
            -[:inferred_trait]->(t:Trait)
            -[:supplier]->(:Resource {resource_id: #{resource}}),
            (q:Page)-[:trait]->(t)
      RETURN p.page_id, q.page_id, t.resource_pk, t.predicate
      LIMIT 100")
    r["data"].map{|row| puts "Inferred: #{row}\n"}
                                 end

  # Create sample hierarchy and resource to test with
  # MERGE queries aren't allowed to have LIMIT clauses.
  # Kludge to prevent the cypher service from complaining: // LIMIT
  def populate(resource, page_origin)

    # Create sample hierarchy
    run_query(
      "MERGE (p1:Page {page_id: #{page_origin+1}, testing: 'yes'})
       MERGE (p2:Page {page_id: #{page_origin+2}, testing: 'yes'})
       MERGE (p3:Page {page_id: #{page_origin+3}, testing: 'yes'})
       MERGE (p4:Page {page_id: #{page_origin+4}, testing: 'yes'})
       MERGE (p5:Page {page_id: #{page_origin+5}, testing: 'yes'})
       MERGE (p2)-[:parent]->(p1)
       MERGE (p3)-[:parent]->(p2)
       MERGE (p4)-[:parent]->(p3)
       MERGE (p5)-[:parent]->(p4)
       // LIMIT")
    # Create silly resource
    run_query(
      "MERGE (:Resource {resource_id: #{resource}})
      // LIMIT")
    # Create silly predicate
    run_query(
      "MERGE (pred:Term {uri: '#{SILLY_TERM}', name: 'silly_predicate'})
      // LIMIT")

    # Create trait to be painted
    r = run_query(
      "MATCH (p2:Page {page_id: #{page_origin+2}}),
             (r:Resource {resource_id: #{resource}}),
             (pred:Term {uri: '#{SILLY_TERM}'})
       RETURN p2.page_id, r.resource_id, pred.name
       LIMIT 10")
    STDERR.puts("Found: #{r["data"]}")
    run_query(
      "MATCH (p2:Page {page_id: #{page_origin+2}}),
             (r:Resource {resource_id: #{resource}}),
             (pred:Term {uri: '#{SILLY_TERM}'})
       MERGE (t2:Trait {eol_pk: 'tt_2_in_resource_#{resource}',
                        resource_pk: 'tt_2', 
                        measurement: 'value of trait'})
       MERGE (t2)-[:predicate]->(pred)
       MERGE (p2)-[:trait]->(t2)
       MERGE (t2)-[:supplier]->(r)
       // LIMIT")
    show(resource)
  end

  # Remove all nodes created by 'populate'

  def flush(resource)
    # Get rid of the test resource MetaData nodes (and their :metadata
    # relationships)
    z = run_query(
      "MATCH (m:MetaData)<-[:metadata]-
             (:Trait)-[:supplier]->
             (:Resource {resource_id: #{resource}})
       WITH m, m.eol_pk AS n
       DETACH DELETE m
       RETURN n
       LIMIT 10000")
    STDERR.puts("Flushed MetaData nodes: #{z["data"]}") if z

    # Get rid of the test resource traits (and their :trait,
    # :inferred_trait, and :supplier relationships)
    z = run_query(
      "MATCH (t:Trait)
             -[:supplier]->(:Resource {resource_id: #{resource}})
       WITH t, t.eol_pk AS n
       DETACH DELETE t
       RETURN n
       LIMIT 10000")
    STDERR.puts("Flushed Trait nodes: #{z["data"]}") if z

    # Get rid of the silly term
    z = run_query(
      "MATCH (t:Term {uri: '#{SILLY_TERM}'})
       WITH t, t.name AS n
       DETACH DELETE t
       RETURN n
       LIMIT 10000")
    STDERR.puts("Flushed Term nodes: #{z["data"]}") if z

    # Get rid of the resource node itself
    z = run_query(
      "MATCH (r:Resource {resource_id: #{resource}})
       WITH r, r.resource_id AS n
       DETACH DELETE r
       RETURN n
       LIMIT 10000")
    STDERR.puts("Flushed Resource nodes: #{z["data"]}") if z

    # Get rid of taxa introduced for testing purposes
    z = run_query(
      "MATCH (p:Page {testing: 'yes'})
       WITH p, p.page_id AS n
       DETACH DELETE p
       RETURN n
       LIMIT 10000")
    STDERR.puts("Flushed Page nodes: #{z["data"]}") if z

    show(resource)

  end

end
