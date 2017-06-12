# Abstraction between our traits and the implementation of thir storage. ATM, we
# use neo4j.
#
# NOTE: in its current state, this is NOT done! Neography uses a plain hash to
# store objects, and ultimately we're going to want our own models to represent
# things. But in these early testing stages, this is adequate. Since this is not
# its final form, there are no specs yet. ...We need to feel out how we want
# this to work, first.
class TraitBank
  # NOTE: should associated pages (below, stored as object_page_id) actually
  # have an association, since we have Pages? ...Yes, but only if that's
  # something we're going to query... and I don't think we do! So all the info
  # is reall in the MySQL DB and thus just the ID is enough.

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
  # * Term: { *uri, *name, *section_ids(csv), definition, comment, attribution,
  #       is_hidden_from_overview, is_hidden_from_glossary, position, type }
  #
  # NOTE: the "type" for Term is one of "measurement", "association", "value",
  #   or "metadata" ... at the time of this writing. I may rename "metadata" to
  #   "units"
  #
  # TODO: add to term: "story" attribute. (And possibly story_attribution. Also
  # an image (which should be handled with an icon) ... and possibly a
  # collection to build a slideshow [using its images].)
  class << self
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

    def query(q)
      start = Time.now
      results = nil
      q.sub(/\A\s+/, "")
      begin
        results = connection.execute_query(q)
        stop = Time.now
      rescue Excon::Error::Socket => e
        Rails.logger.error("Connection refused on query: #{q}")
        sleep(0.1)
        connection.execute_query(q)
      rescue Excon::Error::Timeout => e
        Rails.logger.error("Timed out on query: #{q}")
        sleep(1)
        connection.execute_query(q)
      ensure
        q.gsub!(/ ([A-Z ]+)/, "\n  \\1") if q.size > 80 && q != /\n/
        Rails.logger.warn("  TB TraitBank (#{stop ? stop - start : "F"}): #{q}")
      end
      results
    end

    def quote(string)
      return string if string.is_a?(Numeric) || string =~ /\A[-+]?[0-9,]*\.?[0-9]+\Z/
      %Q{"#{string.gsub(/"/, "\\\"")}"}
    end

    def count
      res = query(
        "MATCH (trait:Trait)<-[:trait]-(page:Page) "\
        "WITH count(trait) as count "\
        "RETURN count")
      res["data"] ? res["data"].first.first : false
    end

    def predicate_count
      Rails.cache.fetch("trait_bank/predicate_count", expires_in: 1.day) do
        res = query(
          "MATCH (trait:Trait)-[:predicate]->(term:Term) "\
          "WITH count(distinct(term.uri)) AS count "\
          "RETURN count")
        res["data"] ? res["data"].first.first : false
      end
    end

    def terms(page = 1, per = 50)
      q = "MATCH (term:Term) RETURN term ORDER BY LOWER(term.name), LOWER(term.uri)"
      q += limit_and_skip_clause(page, per)
      res = query(q)
      res["data"] ? res["data"].map { |t| t.first["data"] } : false
    end

    def limit_and_skip_clause(page = 1, per = 50)
      # I don't know why the default values don't work, but:
      page ||= 1
      per ||= 50
      skip = (page.to_i - 1) * per.to_i
      add = " LIMIT #{per}"
      add = " SKIP #{skip}#{add}" if skip > 0
      add
    end

    def order_clause(options)
      options[:sort] ||= ""
      options[:sort_dir] ||= ""
      sorts = if options[:by]
        options[:by]
      elsif options[:object_term]
        [] # You already have a SINGLE term. Don't sort it.
      elsif options[:sort].downcase == "measurement"
        ["trait.normal_measurement"]
      else
        # TODO: this is not good. multiple types of values will not
        # "interweave", and the only way to change that is to store a
        # "normal_value" value for all different "stringy" types (literals,
        # object terms, and object page names). ...This is a resonable approach,
        # though it will require more work to keep "up to date" (e.g.: if the
        # name of an object term changes, all associated traits will have to
        # change).
        ["LOWER(info_term.name)", "trait.normal_measurement", "LOWER(trait.literal)"]
      end
      sorts << "page.name" unless options[:by]
      dir = options[:sort_dir].downcase == "desc" ? " desc" : ""
      %Q{ ORDER BY #{sorts.join("#{dir}, ")}}
    end

    def trait_exists?(resource_id, pk)
      raise "NO resource ID!" if resource_id.blank?
      raise "NO resource PK!" if pk.blank?
      res = query(
        "MATCH (trait:Trait { resource_pk: #{quote(pk)} })"\
        "-[:supplier]->(res:Resource { resource_id: #{resource_id} }) "\
        "RETURN trait")
      res["data"] ? res["data"].first : false
    end

    def by_trait(full_id, page = 1, per = 200)
      (_, resource_id, id) = full_id.split("--")
      id = %Q{"#{id}"} unless id =~ /\A\d+\Z/
      q = "MATCH (trait:Trait { resource_pk: #{id} })"\
          "-[:supplier]->(resource:Resource { resource_id: #{resource_id} }) "\
        "MATCH (trait)-[:predicate]->(predicate:Term) "\
        "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
        "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
        "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
        "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
        "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "\
        "RETURN resource, trait, predicate, object_term, units, "\
          "meta, meta_predicate, meta_units_term, meta_object_term"
      q += limit_and_skip_clause(page, per)
      res = query(q)
      build_trait_array(res)
    end

    def by_page(page_id, page = 1, per = 100)
      q = "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait)"\
          "-[:supplier]->(resource:Resource) "\
        "MATCH (trait)-[:predicate]->(predicate:Term) "\
        "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
        "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
        "RETURN resource, trait, predicate, object_term, units"
      q += order_clause(by: ["LOWER(predicate.name)", "LOWER(object_term.name)",
        "LOWER(trait.literal)", "trait.normal_measurement"])
      q += limit_and_skip_clause(page, per)
      res = query(q)
      build_trait_array(res)
    end

    # e.g.: uri = "http://eol.org/schema/terms/Habitat"
    # TraitBank.by_predicate(uri)
    def by_predicate(uri, options = {})
      q = match_page_and_clade(options)
      q += "-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource) "\
        "MATCH (trait)-[:predicate]->"
      if options[:object_term]
        q += "(predicate:Term) "
      else
        q += "(predicate:Term { uri: \"#{uri}\" }) "
      end
      if options[:count]
        if options[:object_term]
          q += "MATCH (trait)-[info:object_term]->(info_term:Term { uri: \"#{uri}\" }) "
        end
      else
        if options[:object_term]
          q += "MATCH (trait)-[info:object_term]->(info_term:Term { uri: \"#{uri}\" }) "
        else
          q += "MATCH (trait)-[info]->(info_term:Term) "
        end
      end
      if options[:meta]
        q+= "OPTIONAL MATCH (trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
        "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
        "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "
      end
      q += "WHERE NOT (trait)-[:predicate]->(info_term)" if q =~ /info_term/
      if options[:clade]
        q += "WHERE page.page_id = #{options[:clade]} OR ancestor.page_id = #{options[:clade]} "
      end
      if options[:count]
        q+= "WITH COUNT(DISTINCT(trait)) AS count RETURN count"
      else
        q += "RETURN page, trait, predicate, type(info) AS info_type, info_term, resource"
        if options[:meta]
          q += ", meta, meta_predicate, meta_units_term, meta_object_term"
        end
        q += order_clause(options)
        q += limit_and_skip_clause(options[:page], options[:per])
      end
      res = query(q)
      if options[:count]
        res["data"] ? res["data"].first.first : 0
      else
        build_trait_array(res)
      end
    end

    def by_predicate_count(uri, options = {})
      by_predicate(uri, options.merge(count: true))
    end

    def by_object_term_uri(uri, options = {})
      by_predicate(uri, options.merge(object_term: true))
    end

    def by_object_term_count(uri, options = {})\
      by_predicate(uri, options.merge(object_term: true, count: true))
    end

    def match_page_and_clade(options = {})
      options[:clade] ?
        "MATCH (ancestor:Page { page_id: #{options[:clade]} })<-[:in_clade*]-(page:Page)" :
        "MATCH (page:Page)"
    end

    # NOTE: this is not indexed. It could get slow later, so you should check
    # and optimize if needed. Do not prematurely optimize!
    def search_predicate_terms(q, page = 1, per = 50)
      q = "MATCH (trait)-[:predicate]->(term:Term) "\
        "WHERE term.name =~ \'(?i)^.*#{q}.*$\' RETURN DISTINCT(term) ORDER BY LOWER(term.name)"
      q += limit_and_skip_clause(page, per)
      res = query(q)
      return [] if res["data"].empty?
      res["data"].map { |r| r[0]["data"] }
    end

    def count_predicate_terms(q)
      q = "MATCH (trait)-[:predicate]->(term:Term) "\
        "WHERE term.name =~ \'(?i)^.*#{q}.*$\' RETURN COUNT(DISTINCT(term))"
      res = query(q)
      return [] if res["data"].empty?
      res["data"] ? res["data"].first.first : 0
    end

    # NOTE: this is not indexed. It could get slow later, so you should check
    # and optimize if needed. Do not prematurely optimize!
    def search_object_terms(q, page = 1, per = 50)
      q = "MATCH (trait)-[:object_term]->(term:Term) "\
        "WHERE term.name =~ \'(?i)^.*#{q}.*$\' RETURN DISTINCT(term) ORDER BY LOWER(term.name)"
      q += limit_and_skip_clause(page, per)
      res = query(q)
      return [] if res["data"].empty?
      res["data"].map { |r| r[0]["data"] }
    end

    # NOTE: this is not indexed. It could get slow later, so you should check
    # and optimize if needed. Do not prematurely optimize!
    def count_object_terms(q)
      q = "MATCH (trait)-[:object_term]->(term:Term) "\
        "WHERE term.name =~ \'(?i)^.*#{q}.*$\' RETURN COUNT(DISTINCT(term))"
      res = query(q)
      return [] if res["data"].empty?
      res["data"] ? res["data"].first.first : 0
    end

    def page_exists?(page_id)
      res = query("MATCH (page:Page { page_id: #{page_id} }) "\
        "RETURN page")
      res["data"] ? res["data"].first : false
    end

    # Given a results array and the name of one of the returned columns to treat
    # as the "identifier" (meaning the field who's ID will uniquely identify a
    # row of related data ... e.g.: the "trait" for trait data)
    def results_to_hashes(results, identifier = nil)
      id_col = results["columns"].index(identifier ? identifier.to_s : "trait")
      hashes = []
      previous_id = nil
      hash = nil
      results["data"].each do |row|
        row_id = row[id_col] && row[id_col]["metadata"] &&
          row[id_col]["metadata"]["id"]
        debugger if row_id.nil? # Oooops, you found a row with NO identifier!
        if row_id != previous_id
          previous_id = row_id
          hashes << hash unless hash.nil?
          hash = {}
        end
        results["columns"].each_with_index do |column, i|
          col = column.to_sym

          value = if row[i]
                    row[i].is_a?(Hash) ? row[i]["data"].symbolize_keys : row[i]
                  else
                    nil
                  end
          if hash.has_key?(col)
            # NOTE: this assumes neo4j never naturally returns an array...
            if hash[col].is_a?(Array)
              hash[col] << value
            # If the value is changing (or if it's metadata)...
            elsif hash[col] != value
              # ...turn it into an array and add the new value.
              hash[col] = [hash[col], value]
            # Note the lack of "else" ... if the value is the same as the last
            # row, we ignore it (assuming it's a duplicate value and another
            # column is changing)
            end
          else
            # Metadata will *always* be returned as an array...
            # NOTE: it's important to catch columns that we KNOW could have
            # multiple values for a given "row"! ...Otherwise, the "ignore
            # duplicates" code will cause problems, above. If you know of a
            # column that could have multiple values, you need to add detection
            # for it here.
            # TODO: this isn't a very general solution. Really we should pass in
            # some knowledge of this, either something like "these columns could
            # have multiple values" or the opposite: "these columns identify a
            # row and cannot change". I prefer the latter, honestly.
            if column =~ /\Ameta/
              hash[col] = [value]
            else
              hash[col] = value unless value.nil?
            end
          end
        end
      end
      hashes << hash unless hash.nil? || hash == {}
      # Symbolize everything!
      hashes.each do |k,v|
        if v.is_a?(Hash)
          hashes[k] = v.symbolize_keys
        elsif v.is_a?(Array)
          hashes[k] = v.map { |sv| sv.symbolize_keys }
        end
      end
      hashes
    end

    # NOTE: this method REQUIRES that some fields have a particular name.
    # ...which isn't very generalized, but it will do for our purposes...
    def build_trait_array(results)
      hashes = results_to_hashes(results)
      data = []
      hashes.each do |hash|
        has_info_term = hash.keys.include?(:info_term)
        has_trait = hash.keys.include?(:trait)
        hash.merge!(hash[:trait]) if has_trait
        hash[:page_id] = hash[:page][:page_id] if hash[:page]
        hash[:resource_id] = if hash[:resource]
          hash[:resource][:resource_id]
        else
          "MISSING"
        end
        # TODO: extract method
        if has_info_term && hash[:info_type]
          info_terms = hash[:info_term].is_a?(Hash) ? [hash[:info_term]] :
            Array(hash[:info_term])
          Array(hash[:info_type]).each_with_index do |info_type, i|
            type = info_type.to_sym
            if type == :object_term
              hash[:object_term] = info_terms[i]
            elsif type == :units_term
              hash[:units] = info_terms[i]
            end
          end
        end
        # TODO: extract method
        if hash.has_key?(:meta)
        raise "Metadata not returned as an array" unless
          hash[:meta].is_a?(Array)
        length = hash[:meta].size
          raise "Missing meta column meta_predicate: #{hash.keys}" unless
            hash.has_key?(:meta_predicate)
          [:meta_predicate, :meta_units_term, :meta_object_term].each do |col|
            next unless hash.has_key?(col)
              # debugger unless
              #   hash[col].size == length
              raise ":#{col} data was not the same size as :meta" unless
                hash[col].size == length
          end
          hash[:metadata] = []
          hash[:meta].each_with_index do |meta, i|
            m_hash = meta
            m_hash[:predicate] = hash[:meta_predicate][i]
            m_hash[:object_term] = hash[:meta_object_term][i]
            m_hash[:units] = hash[:meta_units_term][i]
            hash[:metadata] << m_hash
          end
        end
        if has_trait
          hash[:id] = "trait--#{hash[:resource_id]}--#{hash[:resource_pk]}"
          hash[:id] += "--#{hash[:page_id]}" if hash[:page_id]
        end
        data << hash
      end
      data
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

    # TODO: we should probably do some checking here. For example, we should
    # only have ONE of [value/object_term/association/literal].
    def create_trait(options)
      resource_id = options[:supplier]["data"]["resource_id"]
      Rails.logger.warn "++ Create Trait: Resource##{resource_id}, "\
        "PK:#{options[:resource_pk]}"
      if trait = trait_exists?(resource_id, options[:resource_pk])
        Rails.logger.warn "++ Already exists, skipping."
        return trait
      end
      page = options.delete(:page)
      supplier = options.delete(:supplier)
      meta = options.delete(:metadata)
      predicate = parse_term(options.delete(:predicate))
      units = parse_term(options.delete(:units))
      object_term = parse_term(options.delete(:object_term))
      convert_measurement(options, units)
      trait = connection.create_node(options)
      connection.add_label(trait, "Trait")
      relate("trait", page, trait)
      relate("supplier", trait, supplier)
      relate("predicate", trait, predicate)
      relate("units_term", trait, units) if units
      relate("object_term", trait, object_term) if
        object_term
      meta.each { |md| add_metadata_to_trait(trait, md) } unless meta.blank?
      trait
    end

    def relate(how, from, to)
      begin
        connection.create_relationship(how, from, to)
      rescue
        # Try again...
        begin
          sleep(0.1)
          connection.create_relationship(how, from, to)
        rescue Neography::BadInputException => e
          Rails.logger.error("** ERROR adding a #{how} relationship:\n#{e.message}")
          Rails.logger.error("** from: #{from}")
          Rails.logger.error("** to: #{to}")
        rescue Neography::NeographyError => e
          Rails.logger.error("** ERROR adding a #{how} relationship:\n#{e.message}")
          Rails.logger.error("** from: #{from}")
          Rails.logger.error("** to: #{to}")
        rescue Excon::Error::Socket => e
          puts "** TIMEOUT adding relationship"
          Rails.logger.error("** ERROR adding a #{how} relationship:\n#{e.message}")
          Rails.logger.error("** from: #{from}")
          Rails.logger.error("** to: #{to}")
        rescue => e
          puts "Something else happened."
          debugger
          1
        end
      end
    end

    def add_metadata_to_trait(trait, options)
      predicate = parse_term(options.delete(:predicate))
      units = parse_term(options.delete(:units))
      object_term = parse_term(options.delete(:object_term))
      convert_measurement(options, units)
      meta = connection.create_node(options)
      connection.add_label(meta, "MetaData")
      relate("metadata", trait, meta)
      relate("predicate", meta, predicate)
      relate("units_term", meta, units) if units
      relate("object_term", meta, object_term) if
        object_term
      meta
    end

    def add_parent_to_page(parent, page)
      if parent.nil?
        if page.nil?
          puts "** Cannot add :parent relationship from nil to nil!"
        else
          puts "** Cannot add :parent relationship to nil parent for page #{page["data"]["page_id"]}"
        end
      elsif page.nil?
        puts "** Cannot add :parent relationship to nil page to parent #{parent["data"]["page_id"]}"
      end
      begin
        relate("parent", page, parent)
      rescue Neography::PropertyValueException
        puts "** Unable to add :parent relationship from page #{page["data"]["page_id"]} to #{parent["data"]["page_id"]}"
      end
    end

    # NOTE: this only work on IMPORT. Don't try to run it later! TODO: move it
    # to import. ;)
    def convert_measurement(trait, units)
      return unless trait[:literal]
      trait[:measurement] = begin
        Integer(trait[:literal])
      rescue
        Float(trait[:literal]) rescue trait[:literal]
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
      # ^ I got a "Could not set property "uri", class Neography::PropertyValueException here.
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

    def get_name(trait, which = :predicate)
      if trait && trait.has_key?(which)
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
