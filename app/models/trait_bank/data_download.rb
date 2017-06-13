class TraitBank
  class DataDownload

    # I was using this query for testing:

    # q = %Q{MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource)
    # MATCH (trait)-[:predicate]->(predicate:Term { uri: "http://polytraits.lifewatchgreece.eu/terms/MAT" })
    # MATCH (trait)-[info]->(info_term:Term)
    # OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)
    # OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term)
    # OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term)
    # RETURN page, trait, predicate, type(info) AS info_type, info_term, resource,
    # meta, meta_predicate, meta_units_term, meta_object_term
    # ORDER BY trait.normal_measurement, page.name}

    # results = TraitBank.query(q) ; 1
    # hashes = TraitBank.build_trait_array(results) ; 1

    class << self
      def to_arrays(hashes)
        downloader = self.new(hashes)
        downloader.to_arrays
      end
    end

    def initialize(hashes)
      @hashes = hashes
      get_predicates
    end

    def columns
      { "EOL Page ID" => -> (trait, page, resource, value) { page && page.id }, # NOTE: might be nice to make this clickable?
        "Ancestry" => -> (trait, page, resource, value) { page && page.native_node.ancestors.map { |n| n.canonical_form }.join(" | ") },
        "Scientific Name" => -> (trait, page, resource, value) { page && page.scientific_name },
        "Common Name" => -> (trait, page, resource, value) { page && page.vernacular.try(:string) },
        "Measurement" => -> (trait, page, resource, value) {trait[:predicate][:name]},
        "Value" => -> (trait, page, resource, value) {value}, # NOTE this is actually more complicated...
        "Measurement URI" => -> (trait, page, resource, value) {trait[:predicate][:uri]},
        "Value URI" => -> (trait, page, resource, value) {trait[:object_term] && trait[:object_term][:uri]},
        "Units (normalized)" => -> (trait, page, resource, value) {trait[:predicate][:normal_units]},
        "Units URI (normalized)" => -> (trait, page, resource, value) {trait[:predicate][:normal_units]}, # TODO: this won't work; we're not storing it right now. Add it.
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

    def to_arrays
      require "csv"
      pages = Page.where(id: page_ids).
        includes(:medium, :native_node, :preferred_vernaculars)
      resources = Resource.where(id: resource_ids)
      associations = Page.where(id: association_ids)
      cols = columns
      data = []
      data << cols.keys + @predicates.keys
      @hashes.each do |trait|
        page = pages.find { |p| p.id == trait[:page][:page_id] }
        resource = resources.find { |r| r.id == trait[:resource][:resource_id] }
        resource = resources.find { |r| r.id == trait[:resource][:resource_id] }
        value = if trait[:object_page_id]
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
        row = []
        cols.each do |name, lamb|
          row << lamb[trait, page, resource, value]
        end
        @predicates.values.each do |predicate|
          metas = trait[:metadata].select { |m| m[:predicate][:uri] == predicate[:uri] }
          row << if metas.any?
            metas.map do |meta|
              meta[:object_term] ? meta[:object_term][:name] : meta[:literal]
            end.uniq.join(" | ")
          else
            nil
          end
        end
        data << row
      end
      CSV.generate(col_sep: "\t") do |csv|
        data.each { |row| csv << row }
      end
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
      columns = {}
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
