class TraitBank
  class DataDownload
    attr_reader :count

    class << self
      def term_search(term_query)
        downloader = self.new(term_query)
        # TODO: rework/re-enable user downloads for large result sets
#        if downloader.count > 1000
#          UserDownload.create(
#            user_id: options[:user_id],
#            clade: options[:clade],
#            object_terms: options[:object_term],
#            predicates: options[:predicate],
#            count: downloader.count)
#        else
#          downloader.build
#        end
        downloader.build
      end
    end

    def initialize(term_query)
      @query = term_query.clone
      @options = { :per_page => 1000, :meta => true, :result_type => :record }
      # TODO: would be great if we could detect whether a version already exists
      # for download and use that.
      @filename = Digest::MD5.hexdigest(@query.as_json.to_s)
      @filename += ".tsv"
      @count = TraitBank.term_search(@query, @options.merge(:count => true))
    end

    def build
      @hashes = TraitBank.term_search(@query, @options)
      get_predicates
      to_arrays
      generate_csv
    end

    def background_build
      # OOOOPS! We don't actually want to do this here, we want to call a DataDownload. ...which means this logic is in the wrong place. TODO - move.
      # TODO - I am not *entirely* confident that this is memory-efficient
      # with over 1M hits... but I *think* it will work.
      @hashes = []
      TraitBank.batch_term_search(@options) do |batch|
        @hashes += batch
      end
      get_predicates
      to_arrays
      write_csv
      @filename
    end

    # rubocop:disable Lint/UnusedBlockArgument
    def columns # rubocop:disable Metrics/CyclomaticComplexity
      { "EOL Page ID" => -> (trait, page, resource, value) { page && page.id },# NOTE: might be nice to make this clickable?
        "Ancestry" => -> (trait, page, resource, value) { page && page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ") },
        "Scientific Name" => -> (trait, page, resource, value) { page && page.scientific_name },
        "Common Name" => -> (trait, page, resource, value) { page && page.vernacular.try(:string) },
        "Measurement" => -> (trait, page, resource, value) {trait[:predicate][:name]},
        "Value" => -> (trait, page, resource, value) {value}, # NOTE this is actually more complicated...
        "Measurement URI" => -> (trait, page, resource, value) {trait[:predicate][:uri]},
        "Value URI" => -> (trait, page, resource, value) {trait[:object_term] && trait[:object_term][:uri]},
        # TODO: these normalized units won't work; we're not storing it right now. Add it.
        # "Units (normalized)" => -> (trait, page, resource, value) {trait[:predicate][:normal_units]},
        # "Units URI (normalized)" => -> (trait, page, resource, value) {trait[:predicate][:normal_units]},
        "Raw Value (direct from source)" => -> (trait, page, resource, value) {trait[:measurement]},
        "Raw Units (direct from source)" => -> (trait, page, resource, value) {trait[:units] && trait[:units][:name]},
        "Raw Units URI (direct from source)" => -> (trait, page, resource, value) {trait[:units] && trait[:units][:uri]},
        "Statistical Method" => -> (trait, page, resource, value) {trait[:statistical_method]},
        "Life Stage" => -> (trait, page, resource, value) {trait[:lifestage]},
        "Sex" => -> (trait, page, resource, value) {trait[:sex]},
        "Supplier" => -> (trait, page, resource, value) { resource ? resource.name : "unknown" },
        "Content Partner Resource URL" => -> (trait, page, resource, value) { resource ? resource.url : nil },
        "Source" => -> (trait, page, resource, value) {trait[:source]}
      }
    end
    # rubocop:enable Lint/UnusedBlockArgument

    def to_arrays
      require "csv"
      pages = Page.where(id: page_ids).
        includes(:medium, :native_node, :preferred_vernaculars)
      resources = Resource.where(id: resource_ids)
      associations = Page.where(id: association_ids)
      cols = columns
      @data = []
      @data << cols.keys + @predicates.keys
      @hashes.each do |trait|
        page = pages.find { |p| p.id == trait[:page][:page_id] }
        resource = resources.find { |r| r.id == trait[:resource][:resource_id] }
        resource = resources.find { |r| r.id == trait[:resource][:resource_id] }
        value = build_value(trait, associations)
        row = []
        cols.each do |_, lamb|
          row << lamb[trait, page, resource, value]
        end
        @predicates.values.each do |predicate|
          metas = trait[:metadata].select { |m| m[:predicate][:uri] == predicate[:uri] }
          row << metas.any? ? join_metas(metas) : nil
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
      CSV.open("public/#{@filename}", "wb") do |csv|
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
