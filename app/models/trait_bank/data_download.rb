require "zip"
require "csv"
require "set"

class TraitBank
  class DataDownload
    BATCH_SIZE = 1000

    attr_reader :count

    class << self
      def term_search(term_query, user_id, url)
        downloader = self.new(term_query, nil, url)
#        if downloader.count > BATCH_SIZE
#          term_query.save!
#          UserDownload.create(
#            :user_id => user_id,
#            :term_query => term_query,
#            :count => downloader.count
#          )
#        else
#          downloader.build
#        end
         term_query.save!
         UserDownload.create(
           :user_id => user_id,
           :term_query => term_query,
           :count => downloader.count,
           :search_url => url
         )
      end

      def path
        return @path if @path
        @path = Rails.public_path.join('data', 'downloads')
        FileUtils.mkdir_p(@path) unless Dir.exist?(path)
        @path
      end
    end

    def initialize(term_query, count, url)
      @query = term_query
      @options = { :per => BATCH_SIZE, :meta => true }
      # TODO: would be great if we could detect whether a version already exists
      # for download and use that.

      @base_filename = Digest::MD5.hexdigest(@query.as_json.to_s)
      @url = url
      @count = count || TraitBank.term_search(@query, @options.merge(:count => true))
    end

    def background_build
      # OOOOPS! We don't actually want to do this here, we want to call a DataDownload. ...which means this logic is in the wrong place. TODO - move.
      # TODO - I am not *entirely* confident that this is memory-efficient
      # with over 1M hits... but I *think* it will work.
      hashes = []
      TraitBank.batch_term_search(@query, @options, @count) do |batch|
        hashes += batch
      end

      if @query.record?
        TraitBank::RecordDownloadWriter.new(hashes, @base_filename, @url).write
      elsif @query.taxa?
        TraitBank::PageDownloadWriter.write(hashes, @base_filename, @url)
      else
        raise "unsupported result type"
      end
    end
  end
end
