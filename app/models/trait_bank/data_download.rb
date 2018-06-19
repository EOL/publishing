require "zip"
require "csv"
require "set"

class TraitBank
  class DataDownload
    BATCH_SIZE = 1000

    # These are handled as ordered columns
    HEADER_GLOSSARY = {
      "http://rs.tdwg.org/dwc/terms/measurementType" => {
        :label => "Measurement Type",
        :definition => "The nature of the measurement, fact, characteristic, or assertion. Recommended best practice is to use a controlled vocabulary."
      },
      "http://rs.tdwg.org/dwc/terms/measurementValue" => {
        :label => "Measurement Value",
        :definition => "The value of the measurement, fact, characteristic, or assertion."
      },
      "http://rs.tdwg.org/dwc/terms/measurementUnit" => {
        :label => "Measurement Unit",
        :definition => "The units associated with the measurementValue. Recommended best practice is to use the International System of Units (SI)."
      },
      "http://eol.org/schema/terms/statisticalMethod" => {
        :label => "Statistical Method",
        :definition => "The method which was used to process an aggregate of values."
      },
      "http://rs.tdwg.org/dwc/terms/sex" => {
        :label => "Sex",
        :definition => "The sex of the biological individual(s) represented in the Occurrence. Recommended best practice is to use a controlled vocabulary."
      },
      "http://rs.tdwg.org/dwc/terms/lifeStage" => {
        :label => "Life Stage",
        :definition => "The age class or life stage of the biological individual(s) at the time the Occurrence was recorded. Recommended best practice is to use a controlled vocabulary."
      },
      "http://purl.org/dc/terms/source" => {
        :label => "Source",
        :definition => "The described resource may be derived from the related resource in whole or in part. Recommended best practice is to identify the related resource by means of a string conforming to a formal identification system."
      },
      "http://purl.org/dc/terms/bibliographicCitation" => {
        :label => "Bibliographic Citation",
        :definition => "Recommended practice is to include sufficient bibliographic detail to identify the resource as unambiguously as possible."
      },
      "http://purl.org/dc/terms/contributor" => {
        :label => "Contributor",
        :definition => "Examples of a Contributor include a person, an organization, or a service."
      },
      "http://eol.org/schema/reference/referenceID" => {
        :label => "Reference ID",
        :definition => "Reference ID definition"
      }
    }

    IGNORE_META_URIS = HEADER_GLOSSARY.keys

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
      @options = { :per => BATCH_SIZE, :meta => true, :result_type => :record }
      # TODO: would be great if we could detect whether a version already exists
      # for download and use that.

      @base_filename = Digest::MD5.hexdigest(@query.as_json.to_s)
      @zip_filename = "#{@base_filename}.zip"
      @trait_filename = "data_#{@base_filename}.tsv"
      @glossary_filename = "glossary_#{@base_filename}.tsv"
      @count = count || TraitBank.term_search(@query, @options.merge(:count => true))
      @glossary = HEADER_GLOSSARY.clone
      @citations = Set.new
      @ref_id = 0
      @references = {}
      @url = url
    end

    def build
      @hashes = TraitBank.term_search(@query, @options)
      get_predicates
      to_arrays
      generate_csv
    end

    def write_zip
      Zip::File.open(TraitBank::DataDownload.path.join(@zip_filename), Zip::File::CREATE) do |zipfile|
        zipfile.mkdir(@base_filename)
        zipfile.add("#{@base_filename}/#{@trait_filename}", TraitBank::DataDownload.path.join(@trait_filename))
        zipfile.add("#{@base_filename}/#{@glossary_filename}", TraitBank::DataDownload.path.join(@glossary_filename))
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
      write_glossary
      write_zip
      @zip_filename
    end

    def handle_term(term)
      if term
        if term[:uri]
          @glossary[term[:uri]] = {
            :label => term[:name],
            :definition => term[:definition]
          }
        end
        term[:name]
      else
        nil
      end
    end

    # rubocop:disable Lint/UnusedBlockArgument
    def start_cols # rubocop:disable Metrics/CyclomaticComplexity
      { "EOL Page ID" => -> (trait, page, resource) { page && page.id },# NOTE: might be nice to make this clickable?
        "Ancestry" => -> (trait, page, resource) { page && page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ") },
        "Scientific Name" => -> (trait, page, resource) { page && page.scientific_name },
        "Measurement Type" => -> (trait, page, resource) { handle_term(trait[:predicate]) },
        "Measurement Value" => -> (trait, page, resource) do 
          trait[:measurement] || handle_term(trait[:object_term]) # Raw value, not sure if this works for associations
        end,
        "Measurement Unit" => -> (trait, page, resource) { handle_term(trait[:units]) },
        "Measurement Accuracy" => -> (trait, page, resource) { meta_value(trait, "http://rs.tdwg.org/dwc/terms/measurementAccuracy") },
        "Statistical Method" => -> (trait, page, resource) { handle_term(trait[:statistical_method_term]) },
        "Sex" => -> (trait, page, resource) { handle_term(trait[:sex_term])},
        "Life Stage" => -> (trait, page, resource) { handle_term(trait[:lifestage_term]) },
        #"Value" => -> (trait, page, resource) { value }, # NOTE this is actually more complicated...Watch out for associations
        #"Measurement URI" => -> (trait, page, resource) {trait[:predicate][:uri]},
        #"Value URI" => -> (trait, page, resource) {trait[:object_term] && trait[:object_term][:uri]},
        # TODO: these normalized units won't work; we're not storing it right now. Add it.
        # "Units (normalized)" => -> (trait, page, resource) {trait[:predicate][:normal_units]},
        # "Units URI (normalized)" => -> (trait, page, resource) {trait[:predicate][:normal_units]},
        #"Raw Units URI (direct from source)" => -> (trait, page, resource) {trait[:units] && trait[:units][:uri]},
        #"Statistical Method" => -> (trait, page, resource) {trait[:statistical_method]},
        #"Supplier" => -> (trait, page, resource) { resource ? resource.name : "unknown" },
        #"Content Partner Resource URL" => -> (trait, page, resource) { resource ? resource.url : nil },
      }
    end
    # rubocop:enable Lint/UnusedBlockArgument
    
    def handle_citation(cit)
      if !cit.blank?
        @citations.add(cit)
      end

      cit
    end

    def handle_reference(reference)
      if !reference.blank?
        if !@references.key?(reference)
          @references[reference] = @ref_id
          @ref_id += 1
        end
        
        @references[reference]
      else
        nil
      end
    end

    def end_cols
      {
        "Source" => -> (trait, page, resource) { handle_citation(meta_value(trait, "http://purl.org/dc/terms/source")) },
        "Bibliographic Citation" => -> (trait, page, resource) { handle_citation(meta_value(trait, "http://purl.org/dc/terms/bibliographicCitation")) },
        "Contributor" => -> (trait, page, resource) { meta_value(trait, "http://purl.org/dc/terms/contributor") },
        "Reference ID" => -> (trait, page, resource) { handle_reference(meta_value(trait, "http://eol.org/schema/reference/referenceID")) }

      #TODO: deal with references
      }
    end

    def to_arrays
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
        row = []
        start_cols.each do |_, lamb|
          row << lamb[trait, page, resource]
        end
        @predicates.values.each do |predicate|
          @glossary[predicate[:uri]] = {
            :label => predicate[:name],
            :definition => predicate[:definition]
          }
          row << meta_value(trait, predicate[:uri])
        end
        end_cols.each do |_, lamb|
          row << lamb[trait, page, resource]
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
      CSV.open(TraitBank::DataDownload.path.join(@trait_filename), "wb", :col_sep => "\t") do |csv|
        @data.each { |row| csv << row }
      end
    end

    def write_glossary
      CSV.open(TraitBank::DataDownload.path.join(@glossary_filename), "wb", :col_sep => "\t") do |csv|
        csv << ["Glossary"]
        csv << ["Label", "URI", "Definition"]
        @glossary.each do |uri, item|
          csv << [item[:label], uri, item[:definition]]
        end

        csv << []
        csv << ["Sources and citations"]
        @citations.each do |cit|
          csv << [cit]
        end

        csv << []
        csv << ["References"]
        csv << ["Id", "Reference"]
        @references.map { |ref, id| [id, ref] }.sort { |a, b| a[0] <=> b[0] }.each do |pair|
          csv << [pair]
        end

        csv << []
        csv << ["Search URL"]
        csv << [@url]
      end
    end

    def meta_value(trait, uri) 
      metas = trait[:metadata].select { |m| m[:predicate][:uri] == uri }
      metas.any? ? join_metas(metas) : nil
    end

    def join_metas(metas)
      metas.map do |meta|
        meta[:object_term] ? handle_term(meta[:object_term]) : meta[:literal]
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
