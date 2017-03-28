# Abstraction between our traits and the implementation of thir storage. ATM, we
# use neo4j.
#
# NOTE: in its current state, this is NOT done! Neography uses a plain hash to
# store objects, and ultimately we're going to want our own models to represent
# things. But in these early testing stages, this is adequate. Since this is not
# its final form, there are no specs yet. ...We need to feel out how we want
# this to work, first.
class TraitBank
  # The Labels, and their expected relationships { and (*required)properties }:
  # * Resource: { *resource_id }
  # * Page: ancestor(Page), parent(Page), trait(Trait) { *page_id }
  # * Trait: *predicate(Term), *supplier(Resource), metadata(MetaData),
  #          object_term(Term), units_term(Term)
  #     { *resource_pk, *scientific_name, statistical_method, sex, lifestage,
  #       source, measurement, object_page_id, literal, normal_measurement,
  #       normal_units }
  # * MetaData: *predicate(Term), object_term(Term), units_term(Term)
  #     { measurement, literal }
  # * Term: { *uri, *name, *section_ids(csv), , comment, attribution,
  #       is_hidden_from_overview, is_hidden_from_glossary }
  #
  # TODO: add to term: "story" attribute. (And possibly story_attribution. Also
  # an image (which should be handled with an icon) ... and possibly a
  # collection to build a slideshow [using its images].)
  class << self
    # TODO: This doesn't seem to belong here. ...Move?
    def iucn_status_key(record)
      unknown = "unknown"
      return unknown unless record && record[:object_term]
      case record[:object_term][:uri]
      when Eol::Uris::Iucn.ex
        "ex"
      when Eol::Uris::Iucn.ew
        "ew"
      when Eol::Uris::Iucn.cr
        "cr"
      when Eol::Uris::Iucn.en
        "en"
      when Eol::Uris::Iucn.vu
        "vu"
      when Eol::Uris::Iucn.nt
        "nt"
      when Eol::Uris::Iucn.lc
        "lc"
      when Eol::Uris::Iucn.dd
        "dd"
      when Eol::Uris::Iucn.ne
        "ne"
      else
        unknown
      end
    end

    def connection
      @connection ||= Neography::Rest.new(ENV["EOL_TRAITBANK_URL"])
    end

    def ping
      begin
        connection.list_indexes
      rescue Excon::Error::Socket => e
        return false
      end
      true
    end

    # Neography-style:
    def connect
      parts = ENV["EOL_TRAITBANK_URL"].split(%r{[/:@]})
      Neography.configure do |cfg|
        cfg.username = parts[3]
        cfg.password = parts[4]
      end
    end

    # TODO: we want to be wiser, here.
    def query(q)
      begin
        connection.execute_query(q)
      rescue Excon::Error::Timeout => e
        sleep(1)
        connection.execute_query(q)
      end
    end

    def quote(string)
      return string if string.is_a?(Numeric) || string =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
      %Q{"#{string.gsub(/"/, "\\\"")}"}
    end

    def setup
      create_indexes
      create_constraints
    end

    # You only have to run this once, and it's best to do it before loading TB:
    def create_indexes
      indexes = %w{ Page(page_id) Trait(resource_pk) Trait(predicate)
        Term(predicate) MetaData(predicate) }
      indexes.each do |index|
        query("CREATE INDEX ON :#{index};")
      end
    end

    # TODO: Can we create a constraint where a Trait only has one of
    # [measurement, object_page_id, literal, term]? I don't think so... NOTE:
    # You only have to run this once, and it's best to do it before loading TB:
    def create_constraints
      contraints = {
        "Page" => [:page_id],
        "Term" => [:uri]
      }
      contraints.each do |label, fields|
        fields.each do |field|
          begin
            query(
              "CREATE CONSTRAINT ON (o:#{label}) ASSERT o.#{field} IS UNIQUE;"
            )
          rescue Neography::NeographyError => e
            rails e unless e.message =~ /already exists/
          end
        end
      end
    end

    # Your gun, your foot: USE CAUTION. This erases EVERYTHING irrevocably.
    def nuclear_option!
      query("MATCH (n) DETACH DELETE n")
    end

    def trait_count
      res = query(
        "MATCH (trait:Trait)<-[:trait]-(page:Page) "\
        "WITH count(trait) as count "\
        "RETURN count")
      res["data"] ? res["data"].first.first : false
    end

    def trait_exists?(resource_id, pk)
      res = query(
        "MATCH (trait:Trait { resource_pk: #{quote(pk)} })"\
        "-[:supplier]->(res:Resource { resource_id: #{resource_id} }) "\
        "RETURN trait")
      res["data"] ? res["data"].first : false
    end

   # NOTE: given one of the "res" sets here, you can find a particular trait
   # with this: trait_res = results["data"].find { |tr| tr[2] &&
   # tr[2]["data"]["uri"] == "http://purl.obolibrary.org/obo/VT_0001259" }
   #
   # MATCH (page:Page { page_id: 1680 })-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource) MATCH (trait)-[:predicate]->(predicate:Term) OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) OPTIONAL MATCH (trait)-[:units_term]->(units:Term) OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) RETURN resource, trait, predicate, object_term, units, meta, meta_predicate, meta_object_term, meta_units_term LIMIT 20
    def by_page(page_id)
      # TODO: add proper pagination!
      res = query(
        "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait)"\
          "-[:supplier]->(resource:Resource) "\
        "MATCH (trait)-[:predicate]->(predicate:Term) "\
        "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
        "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
        "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
        "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "\
        "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
        "RETURN resource, trait, predicate, object_term, units, meta, "\
          "meta_predicate, meta_object_term, meta_units_term "\
        "LIMIT 2000"
      )
      build_trait_array(res, [:resource, :trait, :predicate, :object_term,
        :units, :meta, :meta_predicate, :meta_object_term, :meta_units_term])
    end

    def by_predicate(predicate, options = {})
      options[:sort] ||= ""
      options[:sort_dir] ||= ""
      sort = if options[:sort].downcase == "measurement"
        "trait.normal_measurement"
      else
        # TODO: this is not good. multiple types of values will not
        # "interweave", and the only way to change that is to store a
        # "normal_value" value for all different "stringy" types (literals,
        # object terms, and object page names). ...This is a resonable approach,
        # though it will require more work to keep "up to date" (e.g.: if the
        # name of an object term changes, all associated traits will have to
        # change).
        "trait.literal, object_term.name, trait.normal_measurement"
      end
      dir = options[:sort_dir].downcase == "desc" ? "desc" : ""
      puts "************"
      puts "** sort: #{sort}"
      puts "** Direction: #{dir}"
      # TODO: pull in more for the metadata...
      res = query(
        "MATCH (page:Page)-[:trait]->(trait:Trait)"\
          "-[:supplier]->(resource:Resource) "\
        "MATCH (trait)-[:predicate]->(predicate:Term { uri: \"#{predicate}\" }) "\
        "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
        "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
        "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
        "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "\
        "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
        "RETURN resource, trait, page, predicate, object_term, units, meta, "\
          "meta_predicate, meta_object_term, meta_units_term "\
        "ORDER BY #{sort} #{dir}"
      )
      build_trait_array(res, [:resource, :trait, :page, :predicate, :object_term,
        :units, :meta, :meta_predicate, :meta_object_term, :meta_units_term])
    end

    def by_object_term_uri(object_term)
      # TODO: pull in more for the metadata...
      res = query(
        "MATCH (page:Page)-[:trait]->(trait:Trait)"\
          "-[:supplier]->(resource:Resource) "\
        "MATCH (trait)-[:predicate]->(predicate:Term) "\
        "MATCH (trait)-[:object_term]->(object_term:Term { uri: \"#{object_term}\" }) "\
        "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
        "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
        "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "\
        "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
        "RETURN resource, trait, page, predicate, object_term, units, meta, "\
          "meta_predicate, meta_object_term, meta_units_term"
      )
      build_trait_array(res, [:resource, :trait, :page, :predicate, :object_term,
        :units, :meta, :meta_predicate, :meta_object_term, :meta_units_term])
    end

    def get_clade_traits(clade_id, predicate)
      ancestors = query("Match (n:Node { node_id: #{clade_id} })-[p:parent*] -> (n2:Node) return n2")
      ancestor_page_ids = get_pages_ids_from_clade(ancestors["data"] ? ancestors["data"] : nil)
      #adding the page
      ancestor_page_ids << clade_id
      traits = []
      ancestor_page_ids.each do |ancestor_page_id|
        res = query(
          "MATCH (page:Page { page_id: #{ancestor_page_id } })-[:trait]->(trait:Trait)"\
            "-[:supplier]->(resource:Resource) "\
          "MATCH (trait)-[:predicate]->(predicate:Term { uri: \"#{predicate}\" }) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
          "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData) "\
          "RETURN resource, trait, page, predicate, object_term, units, meta"
        )
        traits += build_trait_array(res, [:resource, :trait, :page, :predicate, :object_term,
          :units, :meta])
      end
      traits
    end

    def page_exists?(page_id)
      res = query("MATCH (page:Page { page_id: #{page_id} }) "\
        "RETURN page")
      res["data"] ? res["data"].first : false
    end

    def node_exists?(node_id)
      result_node = get_node(node_id)
      result_node ? result_node.first : false
    end

    def get_node(node_id)
      res = query("MATCH (node:Node { node_id: #{node_id} })"\
        "RETURN node")
      res["data"]
    end

    # Neography recognizes the objects we get back, but the format is weird for
    # building pages, so I transform it here (temporarily, for simplicity). The
    # problem is that the results are in a kind of "table" format, where columns
    # on the left are duplicated to allow for multiple values on the right. This
    # detects those duplicates to add them (as an array) to the trait, and adds
    # all of the other data together into one object meant to represent a single
    # trait, and then returns an array of those traits. It's really not as
    # complicated as it seems! This is mostly bookkeeping.
    def build_trait_array(results, col_array)
      traits = []
      previous_id = nil
      col = {}
      col_array.each_with_index { |c, i| col[c] = i }
      results["data"].each do |trait_res|
        resource = get_column_data(:resource, trait_res, col)
        resource_id = resource ? resource["resource_id"] : "MISSING"
        trait = get_column_data(:trait, trait_res, col)
        page = get_column_data(:page, trait_res, col)
        predicate = get_column_data(:predicate, trait_res, col)
        object_term = get_column_data(:object_term, trait_res, col)
        units = get_column_data(:units, trait_res, col)
        meta_data = get_column_data(:meta, trait_res, col)
        unless meta_data.blank?
          meta_data = meta_data.symbolize_keys
          meta_data[:predicate] = get_column_data(:meta_predicate, trait_res, col).try(:symbolize_keys)
          meta_data[:object_term] = get_column_data(:meta_object_term, trait_res, col).try(:symbolize_keys)
          meta_data[:units] = get_column_data(:meta_units_term, trait_res, col).try(:symbolize_keys)
        end
        this_id = "trait:#{resource_id}:#{trait["resource_pk"]}"
        this_id += ":#{page["page_id"]}" if page
        if this_id == previous_id && traits.last && ! meta_data.blank?
          begin
            traits.last[:metadata] ||= []
            traits.last[:metadata] << meta_data
          rescue NoMethodError => e
            puts "++ Could not add:"
            puts meta_data.inspect
            puts "++ attempt to add to last member of #{traits.size} array:"
            puts traits.last.inspect
            puts "++ Sorry."
          end
        else
          trait[:metadata] = meta_data.blank? ? nil : [ meta_data ]
          trait[:page_id] = page["page_id"] if page
          trait[:resource_id] = resource_id if resource_id
          trait[:predicate] = predicate.symbolize_keys if predicate
          trait[:object_term] = object_term.symbolize_keys if object_term
          trait[:units] = units.symbolize_keys if units
          trait[:id] = this_id
          traits << trait.symbolize_keys
        end
        previous_id = this_id
      end
      traits
    end

    def get_column_data(name, results, col)
      return nil unless col.has_key?(name)
      return nil unless results[col[name]].is_a?(Hash)
      results[col[name]]["data"]
    end

    def glossary(traits)
      uris = {}
      traits.each do |trait|
        [:predicate, :units, :object_term].each do |type|
          next unless trait[type] && trait[type].is_a?(Hash)
          uris[trait[type][:uri]] ||= trait[type]
        end
      end
      uris
    end

    def resources(traits)
      resources = Resource.where(id: traits.map { |t| t[:resource_id] }.compact.uniq)
      # A little magic to index an array as a hash:
      Hash[ *resources.map { |r| [ r.id, r ] }.flatten ]
    end

    def create_page(id)
      if page = page_exists?(id)
        return page
      end
      page = connection.create_node(page_id: id)
      connection.add_label(page, "Page")
      page
    end

    def find_resource(id)
      res = query("MATCH (resource:Resource { resource_id: #{id} }) "\
        "RETURN resource LIMIT 1")
      res["data"] ? res["data"].first : false
    end

    def create_resource(id)
      if resource = find_resource(id)
        return resource
      end
      resource = connection.create_node(resource_id: id)
      connection.add_label(resource, "Resource")
      resource
    end

    # NOTE: this doesn't handle associations, yet. That s/b coming soon.
    # TODO: we should probably do some checking here. For example, we should
    # only have ONE of [value/object_term/association/literal].
    def create_trait(options)
      page = options.delete(:page)
      supplier = options.delete(:supplier)
      meta = options.delete(:metadata)
      predicate = parse_term(options.delete(:predicate))
      units = parse_term(options.delete(:units))
      object_term = parse_term(options.delete(:object_term))
      convert_measurement(options, units)
      trait = connection.create_node(options)
      connection.add_label(trait, "Trait")
      connection.create_relationship("trait", page, trait)
      connection.create_relationship("supplier", trait, supplier)
      connection.create_relationship("predicate", trait, predicate)
      connection.create_relationship("units_term", trait, units) if units
      connection.create_relationship("object_term", trait, object_term) if
        object_term
      meta.each { |md| add_metadata_to_trait(trait, md) } unless meta.blank?
      trait
    end

    def add_metadata_to_trait(trait, options)
      predicate = parse_term(options.delete(:predicate))
      units = parse_term(options.delete(:units))
      object_term = parse_term(options.delete(:object_term))
      convert_measurement(options, units)
      meta = connection.create_node(options)
      connection.add_label(meta, "MetaData")
      connection.create_relationship("metadata", trait, meta)
      connection.create_relationship("predicate", meta, predicate)
      connection.create_relationship("units_term", meta, units) if units
      connection.create_relationship("object_term", meta, object_term) if
        object_term
      meta
    end

    def convert_measurement(trait, units)
      return unless trait[:measurement]
      trait[:measurement] = begin
        Integer(trait[:measurement])
      rescue
        Float(trait[:measurement]) rescue trait[:measurement]
      end
      # If we converted it (and thus it is numeric) AND we see units...
      if trait[:measurement].is_a?(Numeric) &&
         units && units["data"] && units["data"]["uri"]
        (n_val, n_unit) = UnitConversions.convert(trait[:measurement],
          units["data"]["uri"])
        trait[:normal_measurement] = n_val
        trait[:normal_units] = n_unit
      else
        trait[:normal_measurement] = trait[:measurement]
        if units && units["data"] && units["data"]["uri"]
          trait[:normal_units] = units["data"]["uri"]
        else
          trait[:normal_units] = "missing"
        end
      end
    end

    # Note: I've named this create_node_in_hierarchy as there is another
    # methods called create_node in neography
    def create_node_in_hierarchy(node_id, page_id)
      if node = node_exists?(node_id)
        return node
      end
      node = connection.create_node(node_id: node_id, page_id: page_id)
      connection.add_label(node, "Node")
    end

    def adjust_node_parent_relationship(node_id, parent_id)
      node = get_node(node_id)
      parent_node = get_node(parent_id)
      begin
        connection.create_relationship("parent", node, parent_node) unless relationship_exists?(node_id, parent_id)
      rescue => e
        puts "** ERROR: #{e.message}. Skipping this parent relationship..."
      end
    end

    def relationship_exists?(node_a, node_b)
      res = query("MATCH (node_a:Node { node_id: #{node_a} }) - [r:parent] - (node_b:Node { node_id: #{node_b} })"\
        "RETURN SIGN(COUNT(r))")
      res["data"] ? res["data"].first.first > 0 : false
    end

    def get_pages_ids_from_clade(result)
      page_ids = []
      if result
        result.each do |element|
          data_element = element.first["data"] ? element.first["data"] : nil
          if data_element
            page_ids << data_element["page_id"]
          end
        end
      end
      page_ids.compact.uniq
    end

    def parse_term(term_options)
      return nil if term_options.nil?
      return term_options if term_options.is_a?(Hash)
      return create_term(term_options)
    end

    def create_term(options)
      if existing_term = term(options[:uri]) # NO DUPLICATES!
        return existing_term
      end
      options[:section_ids] = options[:section_ids] ?
        Array(options[:section_ids]).join(",") : ""
      options[:definition] ||= "{definition missing}"
      options[:definition].gsub!(/\^(\d+)/, "<sup>\\1</sup>")
      term_node = connection.create_node(options)
      connection.add_label(term_node, "Term")
      term_node
    end

    def term(uri)
      res = query("MATCH (term:Term { uri: '#{uri}' }) "\
        "RETURN term")
      return nil unless res["data"] && res["data"].first
      res["data"].first.first
    end

    def term_as_hash(uri)
      hash = term(uri)
      raise ActiveRecord::RecordNotFound if hash.nil?
      # NOTE: this step is slightly annoying:
      hash["data"].symbolize_keys
    end

    def sort_by_values(a, b)
      # TODO: associations
      if a[:literal] && b[:literal]
        a[:literal].downcase.gsub(/<\/?[^>]+>/, "") <=>
          b[:literal].downcase.gsub(/<\/?[^>]+>/, "")
      elsif a[:measurement] && b[:measurement]
        a[:measurement] <=> b[:measurement]
      else
        term_a = get_name(a, :object_term)
        term_b = get_name(b, :object_term)
        if term_a && term_b
          term_a.downcase <=> term_b.downcase
        elsif term_a
          -1
        elsif term_b
          1
        else
          0
        end
      end
    end

    def sort_by_predicates(a, b)
      name_a = get_name(a)
      name_b = get_name(b)
      if name_a && name_b
        if name_a == name_b
          sort_by_values(a,b)
        else
          name_a.downcase <=> name_b.downcase
        end
      elsif name_a
        -1
      elsif name_b
        1
      else
        sort_by_values(a,b)
      end
    end

    def sort(traits, options = {})
      traits.sort do |a, b|
        if options[:by_value]
          sort_by_values(a, b)
        else
          sort_by_predicates(a, b)
        end
      end
    end

    def get_name(trait, which = :predicate)
      if trait.has_key?(which)
        if trait[which].has_key?(:name)
          trait[which][:name]
        elsif trait[which].has_key?(:uri)
          humanize_uri(trait[which][:uri]).downcase
        else
          nil
        end
      else
        nil
      end
    end
  end
end
