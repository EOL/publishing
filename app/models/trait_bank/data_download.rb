class TraitBank
  class DataDownload
    class << self
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
          "Supplier" => -> (trait, page, resource, value) {resource.name},
          "Content Partner Resource URL" => -> (trait, page, resource, value) {resource.url},
          "Source" => -> (trait, page, resource, value) {trait[:source]}
          # "measurement method" => -> (trait, page, resource, value) {},
          # "individual count" => -> (trait, page, resource, value) {},
          # "locality" => -> (trait, page, resource, value) {},
          # "event date" => -> (trait, page, resource, value) {},
          # "measurement remarks" => -> (trait, page, resource, value) {},
          # "measurement determined date" => -> (trait, page, resource, value) {},
          # "occurrence remarks" => -> (trait, page, resource, value) {},
          # "citation" => -> (trait, page, resource, value) {},
          # "References" => -> (trait, page, resource, value) {}
        }
      end

      def to_arrays(hashes)
        require "csv"
        pages = Page.where(id: page_ids(hashes)).
          includes(:medium, :native_node, :preferred_vernaculars)
        resources = Resource.where(id: resource_ids(hashes))
        associations = Page.where(id: association_ids(hashes))
        cols = columns
        data = []
        data << cols.keys
        hashes.each do |trait|
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
          i = 0
          row = []
          cols.each do |name, lamb|
            cols.each { |k,v| row << v[trait, page, resource, value] }
            i += 1
          end
          data << row
        end
        CSV.generate do |csv|
          data.each { |row| csv << row }
        end
      end

      def page_ids(hashes)
        hashes.map { |hash| hash[:page_id] || hash[:page] && hash[:page][:page_id] }.uniq.compact
      end

      def resource_ids(hashes)
        hashes.map { |hash| hash[:resource] && hash[:resource][:resource_id] }.uniq.compact
      end

      def association_ids(hashes)
        hashes.map { |hash| hash[:object_page_id] }.uniq.compact
      end

      # This is duplicated with ApplicationHelper, but I didn't think it was
      # "right" to include that here...
      def first_cap(string)
        return string unless string.is_a?(String)
        string.slice(0,1).capitalize + string.slice(1..-1)
      end
    end
  end
end
