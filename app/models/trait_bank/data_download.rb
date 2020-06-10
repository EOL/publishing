require "zip"
require "csv"
require "set"

class TraitBank
  class DataDownload
    BATCH_SIZE = 10_000
    TMPDIR = Rails.application.root.join("data", "tmp")

    attr_reader :count

    class << self
      # options:
      #   - force_new: true -- always create and background_build a UserDownload
      def term_search(term_query, user_id, url, options={})
        count = TraitBank.term_search(
          term_query,
          { count: true },
        ).primary_for_query(term_query)

        UserDownload.create_and_run_if_needed!({
          :user_id => user_id,
          :count => count,
          :search_url => url
        }, term_query, options)
      end

      def path
        return @path if @path
        @path = Rails.public_path.join('data', 'downloads')
        FileUtils.mkdir_p(@path) unless Dir.exist?(path)
        @path
      end
    end

    def initialize(term_query, count, url)
      raise TypeError.new("count cannot be nil") if count.nil?
      @query = term_query
      @options = { per: BATCH_SIZE, meta: true, cache: false }
      # TODO: would be great if we could detect whether a version already exists
      # for download and use that.

      @base_filename = "#{Digest::MD5.hexdigest(@query.as_json.to_s)}_#{Time.now.to_i}"
      @url = url
      @count = count
    end

    def background_build
      # OOOOPS! We don't actually want to do this here, we want to call a DataDownload. ...which means this logic is in the wrong place. TODO - move.
      # TODO - I am not *entirely* confident that this is memory-efficient
      # with over 1M hits... but I *think* it will work.

      hashes = []
      tmpfile_name = "#{@base_filename}_query_results.json"
      tmpfile_path = TMPDIR.join(tmpfile_name)

      Delayed::Worker.logger.info("beginning data download query for #{@query.to_s}, writing results to #{tmpfile_path}")

      File.open(tmpfile_path, "w+") do |tmpfile|
        TraitBank.batch_term_search(@query, @options, @count) do |batch|
          tmpfile.write(batch.to_json)
          tmpfile.write("\n")
          #hashes.concat(batch)
        end

        
        Delayed::Worker.logger.info("finished querying, reading tmpfile #{tmpfile_path}")
        tmpfile.rewind

        tmpfile.each do |line|
          hashes.concat(JSON.parse(line, symbolize_names: true))
        end
      end

      Delayed::Worker.logger.info("finished reading tmpfile #{tmpfile_path}, removing")

      File.delete(tmpfile_path)

      Delayed::Worker.logger.info("writing csv")

      filename = if @query.record?
                   TraitBank::RecordDownloadWriter.new(hashes, @base_filename, @url).write
                 elsif @query.taxa?
                   TraitBank::PageDownloadWriter.write(hashes, @base_filename, @url)
                 else
                   raise "unsupported result type"
                 end

      Delayed::Worker.logger.info("finished data download")
      filename
    end
  end
end
