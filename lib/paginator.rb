# Utility for paginating Cypher queries.
# Writes pages to .csv files, then concatenates them all.
# Does rudimentary error recovery.
# Could be more parallel than it is.

# Writes to stdout if @path is nil

# If the script is interrupted, it can be run again and it will use
# files created on a previous run, if the previous run was in the same
# calendar month.  This is a time saving measure.

# Thanks to Bill Tozier (https://github.com/vaguery) for code review;
# but he is not to be held responsible for anything you see here.

require 'csv'
require 'fileutils'

# These are required if we want to be an HTTP client:
require 'net/http'
require 'json'
require 'cgi'

class Paginator

  # The query_fn takes a CQL query as input, executes it, and returns
  # a result set.  The result set is returned in the idiosyncratic
  # form delivered by neo4j.  The implementation of the query_fn might
  # use neography, or the EOL web API, or any other method for
  # executing CQL queries.

  def initialize(query_fn)
    @query_fn = query_fn
  end

  # -----

  # supervise_query: generate a set of 'pages', then put them
  # together into a single .csv file.

  # A page is the result set of a single cypher query.  The queries
  # are in a single supervise_query call are all the same, except for
  # the value of the SKIP parameter.

  # The reason for this is that the result sets for some queries are
  # too big to capture with a single query, due to timeouts or other
  # problems.

  # Each page is placed in its own file.  If a page file already
  # exists the query is not repeated - the results from the previous
  # run are used directly without verification.

  def supervise_query(query, headings, pagesize, path, skipping=true)
    if File.exist?(path)
      STDERR.puts "Using cached file #{path}"
      path
    else
      # Create a directory path.parts to hold the pages
      pages_dir = path + ".parts"
      if Dir.exist?(pages_dir) && Dir.entries(pages_dir).length > 2
        STDERR.puts "There are cached results in #{pages_dir}"
      end
      begin
        pages, count = get_query_pages(query, headings, pagesize, pages_dir, skipping)
        if count > 0
          STDERR.puts("#{File.basename(path)}: #{pages.length} pages, #{count} records")
        end
        # This always writes a .csv file to path, even if it's empty.
        assemble_pages(pages, path)
        if Dir.exist?(pages_dir) && Dir.entries(pages_dir).length <= 2 # . and ..
          FileUtils.rmdir pages_dir
        end
        path
      rescue => e
        STDERR.puts "** Failed to generate #{path}"
        STDERR.puts "** Exception: #{e}"
        STDERR.puts e.backtrace.join("\n")
        nil
      end
    end
  end

  # Ensure that all the pages files for a table exist, using Neo4j to
  # obtain them as needed.
  # Returns a list of paths (file names for the pages) and a count of
  # the total number of rows (not always accurate).
  # A file will be created for every successful query, but the pathname
  # is only included in the returned list if it contains at least one row.

  def get_query_pages(query, headings, pagesize, pages_dir, skipping)
    limit = (pagesize ? "#{pagesize}" : "10000000")
    pages = []
    skip = 0

    # Keep doing queries until no more results are returned, or until
    # something goes wrong
    while true
      # Fetch it one page at a time
      basename = (pagesize ? "#{skip}_#{pagesize}" : "#{skip}")
      part_path = File.join(pages_dir, "#{basename}.csv")
      if File.exist?(part_path)
        if File.size(part_path) > 0
          pages.push(part_path)
        end
        # Ideally, we should increase skip by the actual number of
        # records in the file.
        skip += pagesize if pagesize
      else
        whole_query = query
        if skipping
          whole_query = whole_query + " SKIP #{skip}"
        end
        whole_query = whole_query + " LIMIT #{limit}"
        result = run_query(whole_query)
        if result
          got = result["data"].length
          # The skip == 0 test is a kludge that fixes a bug where the
          # header row was being omitted in some cases
          STDERR.puts(result) if got == 0
          if got > 0 || skip == 0
            emit_csv(result, headings, part_path)
            pages.push(part_path)
          else
            FileUtils.mkdir_p File.dirname(part_path)
            FileUtils.touch(part_path)
          end
          skip += got
          break if pagesize && got < pagesize
        else
          STDERR.puts("No results for #{part_path}")
          STDERR.puts(whole_query)
        end
      end
      break unless pagesize
    end
    [pages, skip]
  end

  # Combine the pages files (for a single table) into a single master
  # .csv file which is stored at path.
  # Always returns path, where a file (perhaps empty) will be found.

  def assemble_pages(pages, path)
    # Concatenate all the pages together
    FileUtils.mkdir_p File.dirname(path)
    if pages.size == 0
      FileUtils.touch(path)
    elsif pages.size == 1
      FileUtils.mv pages[0], path
    else
      temp = path + ".new"
      tails = pages.drop(1).map { |path| "tail +2 #{path}" }
      more = tails.join(';')
      command = "(cat #{pages[0]}; #{more}) >#{temp}"
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

  # Utility - convert native cypher output form to CSV
  def emit_csv(start, headings, path)
    # Sanity check the result
    if start["columns"] == nil or start["data"] == nil
      STDERR.puts "** failed to write #{path}; result = #{start}"
      return nil
    end
    temp = path + ".new"
    FileUtils.mkdir_p File.dirname(temp)
    csv = CSV.open(temp, "wb")
    if headings
      csv << headings
    else
      csv << start["columns"]
    end
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

end
