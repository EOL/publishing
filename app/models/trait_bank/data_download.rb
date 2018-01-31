require 'zip'

class TraitBank
  class DataDownload
    BATCH_SIZE = 1000

    # These are handled as ordered columns
    IGNORE_META_URIS = [
      "http://rs.tdwg.org/dwc/terms/measurementAccuracy",
      "http://purl.org/dc/terms/bibliographicCitation",
      "http://purl.org/dc/terms/contributor",
      "http://eol.org/schema/reference/referenceID"
    ]

    attr_reader :count

    class << self
      def term_search(term_query, user_id, count = nil)
        downloader = self.new(term_query, count)
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
           :count => downloader.count
         )
      end

      def path
        return @path if @path
        @path = Rails.public_path.join('data', 'downloads')
        FileUtils.mkdir_p(@path) unless Dir.exist?(path)
        @path
      end
    end

    def initialize(term_query, count = nil)
      @query = term_query
      @options = { :per => BATCH_SIZE, :meta => true, :result_type => :record }
      # TODO: would be great if we could detect whether a version already exists
      # for download and use that.

      @base_filename = Digest::MD5.hexdigest(@query.as_json.to_s)
      @zip_filename = "#{@base_filename}.zip"
      @trait_filename = "traits.tsv"
      @count = count || TraitBank.term_search(@query, @options.merge(:count => true))
    end

    def build
      @hashes = TraitBank.term_search(@query, @options)
      get_predicates
      to_arrays
      generate_csv
    end

    def write_zip
      Zip::File.open(File.join(TraitBank::DataDownload.path, @zip_filename), Zip::File::CREATE) do |zipfile|
        zipfile.mkdir(@base_filename)
        zipfile.add("#{@base_filename}/#{@trait_filename}", File.join(TraitBank::DataDownload.path, @trait_filename))
      end
    end

    def background_build
      # OOOOPS! We don't actually want to do this here, we want to call a DataDownload. ...which means this logic is in the wrong place. TODO - move.
      # TODO - I am not *entirely* confident that this is memory-efficient
      # with over 1M hits... but I *think* it will work.
      @hashes = []
      TraitBank.batch_term_search(@query, @options, @count) do |batch|
        @hashes += batch
      end
      get_predicates
      to_arrays
      write_csv
      write_zip
      @zip_filename
    end


    # rubocop:disable Lint/UnusedBlockArgument
    def start_cols # rubocop:disable Metrics/CyclomaticComplexity
      { "EOL Page ID" => -> (trait, page, resource, value) { page && page.id },# NOTE: might be nice to make this clickable?
        "Ancestry" => -> (trait, page, resource, value) { page && page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ") },
        "Scientific Name" => -> (trait, page, resource, value) { page && page.scientific_name },
        "Measurement Type" => -> (trait, page, resource, value) {trait[:predicate][:name]},
        "Measurement Value" => -> (trait, page, resource, value) {trait[:measurement]}, # Raw value, not sure if this works for associations
        "Measurement Units" => -> (trait, page, resource, value) {trait[:units] && trait[:units][:name]},
        "Measurement Accuracy" => -> (trait, page, resource, value) { meta_value(trait, "http://rs.tdwg.org/dwc/terms/measurementAccuracy") },
        "Statistical Method" => -> (trait, page, resource, value) {trait[:statistical_method]},
        "Sex" => -> (trait, page, resource, value) {trait[:sex]},
        "Life Stage" => -> (trait, page, resource, value) {trait[:lifestage]},
        #"Value" => -> (trait, page, resource, value) { value }, # NOTE this is actually more complicated...Watch out for associations
        #"Measurement URI" => -> (trait, page, resource, value) {trait[:predicate][:uri]},
        #"Value URI" => -> (trait, page, resource, value) {trait[:object_term] && trait[:object_term][:uri]},
        # TODO: these normalized units won't work; we're not storing it right now. Add it.
        # "Units (normalized)" => -> (trait, page, resource, value) {trait[:predicate][:normal_units]},
        # "Units URI (normalized)" => -> (trait, page, resource, value) {trait[:predicate][:normal_units]},
        #"Raw Units URI (direct from source)" => -> (trait, page, resource, value) {trait[:units] && trait[:units][:uri]},
        #"Statistical Method" => -> (trait, page, resource, value) {trait[:statistical_method]},
        #"Supplier" => -> (trait, page, resource, value) { resource ? resource.name : "unknown" },
        #"Content Partner Resource URL" => -> (trait, page, resource, value) { resource ? resource.url : nil },
      }
    end
    # rubocop:enable Lint/UnusedBlockArgument
    
    def end_cols
      {
        "Source" => -> (trait, page, resource, value) {trait[:source]},
        "Bibliographic Citation" => -> (trait, page, resource, value) { meta_value(trait, "http://purl.org/dc/terms/bibliographicCitation") },
        "Contributor" => -> (trait, page, resource, value) { meta_value(trait, "http://purl.org/dc/terms/contributor") },
        #"Reference" => -> (trait, page, resource, value) { meta_value(trait, "http://eol.org/schema/reference/referenceID") }

      #TODO: deal with references
      }
    end

    def to_arrays
      require "csv"
      pages = Page.where(id: page_ids).
        includes(:medium, :native_node, :preferred_vernaculars)
      resources = Resource.where(id: resource_ids)
      associations = Page.where(id: association_ids)
      @data = []
      @data << start_cols.keys + @predicates.keys + end_cols.keys
      @hashes.each do |trait|
        page = pages.find { |p| p.id == trait[:page][:page_id] }
        resource = resources.find { |r| r.id == trait[:resource][:resource_id] }
        resource = resources.find { |r| r.id == trait[:resource][:resource_id] }
        value = build_value(trait, associations)
        row = []
        start_cols.each do |_, lamb|
          row << lamb[trait, page, resource, value]
        end
        @predicates.values.each do |predicate|
          row << meta_value(trait, predicate[:uri])
        end
        end_cols.each do |_, lamb|
          row << lamb[trait, page, resource, value]
        end
        @data << row
      end
    end

    def generate_csv
      CSV.generate(col_sep: "\t") do |csv|
        @data.each { |row| csv << row }
      end
    end

    def write_csv
      CSV.open(TraitBank::DataDownload.path.join(@trait_filename), "wb") do |csv|
        @data.each { |row| csv << row }
      end
    end

    def build_value(trait, associations) # rubocop:disable Metrics/CyclomaticComplexity
      if trait[:object_page_id]
        target = associations.find { |a| a.id == trait[:object_page_id] }
        target || "[page #{trait[:object_page_id]} not imported]"
      elsif trait[:measurement]
        first_cap(trait[:measurement])
      elsif trait[:object_term] && trait[:object_term][:name]
        trait[:object_term][:name]
      elsif trait[:literal]
        first_cap(trait[:literal])
      else
        "unknown (missing)"
      end
    end

    def meta_value(trait, uri) 
      metas = trait[:metadata].select { |m| m[:predicate][:uri] == uri }
      metas.any? ? join_metas(metas) : nil
    end

    def join_metas(metas)
      metas.map do |meta|
        meta[:object_term] ? meta[:object_term][:name] : meta[:literal]
      end.uniq.join(" | ")
    end

    def page_ids
      @hashes.map { |hash| hash[:page_id] || hash[:page] && hash[:page][:page_id] }.uniq.compact
    end

    def resource_ids
      @hashes.map { |hash| hash[:resource] && hash[:resource][:resource_id] }.uniq.compact
    end

    def association_ids
      @hashes.map { |hash| hash[:object_page_id] }.uniq.compact
    end

    def get_predicates
      @predicates = {}
      @hashes.each do |hash|
        next unless hash[:metadata]
        hash[:metadata].each do |meta|
          next if IGNORE_META_URIS.include?(meta[:predicate][:uri])
          name = meta[:predicate][:name].titleize rescue ""
          name ||= meta[:predicate][:uri]
          @predicates[name] ||= meta[:predicate]
        end
      end
    end

    # This is duplicated with ApplicationHelper, but I didn't think it was
    # "right" to include that here...
    def first_cap(string)
      return string unless string.is_a?(String)
      string.slice(0,1).capitalize + string.slice(1..-1)
    end
  end
end
