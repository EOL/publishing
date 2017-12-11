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

  # The Labels, and their expected relationships { and (*required) properties }:
  # * Resource: { *resource_id }
  # * Page: ancestor(Page)[NOTE: unused as of Nov2017], parent(Page), trait(Trait) { *page_id }
  # * Trait: *predicate(Term), *supplier(Resource), metadata(MetaData), object_term(Term), units_term(Term)
  #     { *eol_pk, *resource_pk, *scientific_name, statistical_method, sex, lifestage,
  #       source, measurement, object_page_id, literal, normal_measurement,
  #       normal_units[NOTE: this is a literal STRING, used as symbol in Ruby] }
  # * MetaData: *predicate(Term), object_term(Term), units_term(Term)
  #     { *eol_pk, measurement, literal }
  # * Term: parent_term(Term) { *uri, *name, *section_ids(csv), definition, comment,
  #     attribution, is_hidden_from_overview, is_hidden_from_glossary, position,
  #     type }
  #
  # NOTE: the "type" for Term is one of "measurement", "association", "value",
  #   or "metadata" ... at the time of this writing.

  CHILD_TERM_DEPTH = 4

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
        q.gsub!(/ +([A-Z ]+)/, "\n\\1") if q.size > 80 && q !~ /\n/
        Rails.logger.warn(">>TB TraitBank (#{stop ? stop - start : "F"}):\n#{q}")
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

    # TODO: add association to the sort... normal_measurement comes after
    # literal, so it will be ignored
    def order_clause_array(options)
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
        ["LOWER(predicate.name)", "LOWER(info_term.name)", "trait.normal_measurement", "LOWER(trait.literal)"]
      end
      # NOTE: "ties" for traits are resolved by species name.
      sorts << "page.name" unless options[:by]
      if options[:sort_dir].downcase == "desc"
        sorts.map! { |sort| "#{sort} DESC" }
      end
      sorts
    end

    def order_clause(options)
      %Q{ ORDER BY #{order_clause_array(options).join(", ")}}
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
      q = "MATCH (trait:Trait { resource_pk: '#{id.gsub("'", "''")}' })"\
          "-[:supplier]->(resource:Resource { resource_id: #{resource_id} }) "\
          "MATCH (trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
          "OPTIONAL MATCH (trait)-[data]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
          "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
          "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "\
          "RETURN resource, trait, predicate, object_term, units, "\
            "meta, meta_predicate, meta_units_term, meta_object_term "\
          "ORDER BY LOWER(meta_predicate.name)"
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

    def first_pages_for_resource(resource_id)
      q = "MATCH (page:Page)-[:trait]->(:Trait)-[:supplier]->(:Resource { resource_id: #{resource_id} }) "\
        "RETURN DISTINCT(page) LIMIT 10"
      res = query(q)
      found = res["data"]
      return nil unless found
      found.map { |f| f.first["data"]["page_id"] }
    end

    def key_data(page_id)
      q = "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait)"\
        "MATCH (trait)-[:predicate]->(predicate:Term) "\
        "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
        "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
        "RETURN trait, predicate, object_term, units "\
        "ORDER BY predicate.position, LOWER(object_term.name), "\
          "LOWER(trait.literal), trait.normal_measurement "\
        "LIMIT 100"
        # NOTE "Huge" limit, in case there are TONS of values for the same
        # predicate.
      res = query(q)
      build_trait_array(res).group_by { |r| r[:predicate] }
    end

    # NOTE the match clauses are hashes. Values represent the "where" clause.
    def empty_query
      { match: {}, optional: {}, with: [], return: [], order: [] }
    end

    def adv_query(clauses)
      raise "no matches" unless clauses[:match].is_a?(Hash)
      raise "no returns" unless clauses.has_key?(:return)
      q = clause_with_where(clauses[:match], "MATCH")
      q += clause_with_where(clauses[:optional], "OPTIONAL MATCH")
      q += simple_clause(clauses[:with], "WITH")
      q += simple_clause(clauses[:return], "RETURN", ",")
      q += simple_clause(clauses[:order], "ORDER BY", ",")
      q += limit_and_skip_clause(clauses[:page], clauses[:per]) unless clauses[:count]
      query(q)
    end

    def clause_with_where(hash, directive)
      q = ""
      hash.each do |key, value|
        q += " #{directive} #{key} "
        q += "WHERE #{Array(value).join(" AND ")} " unless value.blank?
      end
      q.sub(/ $/, "")
    end

    def simple_clause(clause, directive, joiner = nil)
      joiner ||= directive
      if clause && ! clause.empty?
        " #{directive} " + clause.join(" #{joiner} ")
      else
        ""
      end
    end

    # NOTE: "count" means something different here! In .term_search it's used to
    # indicate you *want* the count; here it means you HAVE the count and are
    # passing it in! Be careful.
    def batch_term_search(term_query, options, count)
      found = 0
      batch_found = 1 # Placeholder; will update in query.
      page = 1
      while(found < count && batch_found > 0)
        batch = TraitBank.term_search(term_query, options.merge(page: page))
        batch_found = batch.size
        found += batch_found
        yield(batch)
        page += 1
      end
    end

    def term_search(term_query, options={})
      q = if options[:result_type] == :record
        term_record_search(term_query, options)
      else
        term_page_search(term_query, options)
      end

      limit_and_skip = options[:page] ? limit_and_skip_clause(options[:page], options[:per]) : ""
      q = "#{q} "\
          "#{limit_and_skip}"
      res = query(q)

      if options[:count]
        res["data"] ? res["data"].first.first : 0
      else
        build_trait_array(res)
      end
    end

    def parent_terms
      @parent_terms ||= "parent_term*0..#{CHILD_TERM_DEPTH}"
    end

    def term_record_search(term_query, options)
      with_count_clause = options[:count] ?
                          "WITH count(*) AS count " :
                          ""
      match_part =
        "MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource)"
      match_part += ", (trait)-[:predicate]->(predicate:Term)" if term_query.search_pairs.empty?
      match_part += ", (page)-[:parent*]->(Page { page_id: #{term_query.clade} })" if term_query.clade

      i = 0
      term_query.search_pairs.map do |pair|
        i += 1
        if pair.object
          match_part += ", (tgt_pred_#{i}:Term{ uri: \"#{pair.predicate}\" })"
          match_part += ", (tgt_obj_#{i}:Term{ uri: \"#{pair.object}\" })"
          match_part += ", (tgt_pred_#{i})<-[#{parent_terms}]-"\
                        "(predicate:Term)<-[:predicate]-(trait)-[:object_term]->(object_term:Term)"\
                        "-[#{parent_terms}]->(tgt_obj_#{i})"
        else
          match_part += ", (tgt_pred_#{i}:Term{ uri: \"#{pair.predicate}\" })"
          match_part += ", (trait)-[:predicate]->(predicate:Term)-[#{parent_terms}]->(tgt_pred_#{i})"
        end
      end

      optional_matches = ["(trait)-[info:units_term|object_term]->(info_term:Term)"]
      optional_matches += [
        "(trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)",
        "(meta)-[:units_term]->(meta_units_term:Term)",
        "(meta)-[:object_term]->(meta_object_term:Term)"
      ] if options[:meta]
      optional_match_part = optional_matches.map { |match| "OPTIONAL MATCH #{match}" }.join("\n")

      orders = ["LOWER(predicate.name)", "LOWER(info_term.name)", "trait.normal_measurement", "LOWER(trait.literal)"]
      orders << "meta_predicate.name" if options[:meta]
      order_part = options[:count] ? "" : "ORDER BY #{orders.join(", ")}"

      returns = if options[:count]
        ["count"]
      else
        ["page", "trait", "predicate", "TYPE(info) AS info_type", "info_term", "resource"]
      end

      if options[:meta] && !options[:count]
        returns += ["meta", "meta_predicate", "meta_units_term", "meta_object_term"]
      end

      return_clause = "RETURN #{returns.join(", ")}"

      "#{match_part} "\
      "#{optional_match_part} "\
      "#{with_count_clause}"\
      "#{return_clause} "\
      "#{order_part} "
    end

    def term_page_search(term_query, options)
      with_count_clause = options[:count] ?
        "WITH COUNT(DISTINCT(page)) AS count " :
        ""
      return_clause = options[:count] ?
        "RETURN count" :
        "RETURN page"
      page_match = "MATCH (page:Page)"
      page_match += "-[:parent*]->(Page { page_id: #{term_query.clade} })" if term_query.clade

      trait_matches = term_query.search_pairs.each_with_index.map do |pair, i|
        trait_label = "t#{i}"
        match = "MATCH (page) -[:trait]-> (#{trait_label}:Trait), "

        if pair.object
          match += "(:Term{ uri: \"#{pair.predicate}\" })<-[:predicate|#{parent_terms}]-"\
          "(#{trait_label})"\
          "-[:object_term|#{parent_terms}]->(:Term{ uri: \"#{pair.object}\" })"
        else
          match += "(#{trait_label})-[:predicate|#{parent_terms}]->(:Term{ uri: \"#{pair.predicate}\" })"
        end

        match
      end

      order_part = options[:count] ? "" : "ORDER BY page.name"

      "#{page_match} "\
      "#{trait_matches.join(" ")} "\
      "#{with_count_clause}"\
      "#{return_clause} "\
      "#{order_part}"
    end

# TODO: update and restore these methods (if needed)
#    def by_predicate(uri, options = {})
#      term_search(options.merge(predicate: uri))
#    end
#
#    def by_predicate_count(uri, options = {})
#      term_search(options.merge(predicate: uri, count: true))
#    end
#
#    def by_object_term_uri(uri, options = {})
#      term_search(options.merge(object_term: uri))
#    end
#
#    def by_object_term_count(uri, options = {})\
#      term_search(options.merge(object_term: uri, count: true))
#    end

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
      res = query("MATCH (page:Page { page_id: #{page_id} }) RETURN page")
      res["data"] && res["data"].first ? res["data"].first.first : false
    end

    def page_has_parent?(page, page_id)
      node = Neography::Node.load(page["metadata"]["id"], connection)
      return false unless node.rel?(:parent)
      node.outgoing(:parent).map { |n| n[:page_id] }.include?(page_id)
    end

    # Given a results array and the name of one of the returned columns to treat
    # as the "identifier" (meaning the field who's ID will uniquely identify a
    # row of related data ... e.g.: the "trait" for trait data)
    def results_to_hashes(results, identifier = nil)
      id_col = results["columns"].index(identifier ? identifier.to_s : "trait")
      id_col ||= 0 # If there is no trait column and nothing was specified...
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

          # This is pretty complicated. It symbolizes any hash that might be a
          # return value, and leaves it alone otherwise. It also checks for a
          # value in "data" first, but returns whatever it gets if that is
          # missing. Just being flexible, since neography returns a variety of
          # results.
          value = if row[i]
                    if row[i].is_a?(Hash)
                      if row[i]["data"].is_a?(Hash)
                        row[i]["data"].symbolize_keys
                      else
                        row[i]["data"] ? row[i]["data"] : row[i].symbolize_keys
                      end
                    else
                      row[i]
                    end
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
          if hash[:resource].is_a?(Array)
            hash[:resource].first[:resource_id]
          else
            hash[:resource][:resource_id]
          end
        else
          "MISSING"
        end
        if hash[:predicate].is_a?(Array)
          Rails.logger.error("Trait {#{hash[:trait][:resource_pk]}} from resource #{hash[:resource_id]} has "\
            "#{hash[:predicate].size} predicates")
          hash[:predicate] = hash[:predicate].first
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
          raise "Metadata not returned as an array" unless hash[:meta].is_a?(Array)
          length = hash[:meta].size
          raise "Missing meta column meta_predicate: #{hash.keys}" unless hash.has_key?(:meta_predicate)
          [:meta_predicate, :meta_units_term, :meta_object_term].each do |col|
            next unless hash.has_key?(col)
            raise ":#{col} data was not the same size as :meta" unless hash[col].size == length
          end
          hash[:meta].compact!
          hash[:metadata] = []
          unless hash[:meta].empty?
            hash[:meta].each_with_index do |meta, i|
              m_hash = meta
              m_hash[:predicate] = hash[:meta_predicate][i]
              m_hash[:object_term] = hash[:meta_object_term][i]
              m_hash[:units] = hash[:meta_units_term][i]
              hash[:metadata] << m_hash
            end
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
      connection.set_label(page, "Page")
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
      connection.set_label(resource, "Resource")
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
      connection.set_label(trait, "Trait")
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
      connection.set_label(meta, "MetaData")
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
          return { added: false, message: 'Cannot add parent from nil to nil!' }
        else
          return { added: false, message: "Cannot add parent to nil parent for page #{page["data"]["page_id"]}" }
        end
      elsif page.nil?
        return { added: false, message: "Cannot add parent for nil page to parent #{parent["data"]["page_id"]}" }
      end
      if page["data"]["page_id"] == parent["data"]["page_id"]
        return { added: false, message: "Skipped adding :parent relationship to itself: #{parent["data"]["page_id"]}" }
      end
      begin
        relate("parent", page, parent)
        return { added: true }
      rescue Neography::PropertyValueException
        return { added: false, message: "Cannot add parent for page #{page["data"]["page_id"]} to "\
          "#{parent["data"]["page_id"]}" }
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
        return existing_term unless options.delete(:force)
      end
      options[:section_ids] = options[:section_ids] ?
        Array(options[:section_ids]).join(",") : ""
      options[:definition] ||= "{definition missing}"
      options[:definition].gsub!(/\^(\d+)/, "<sup>\\1</sup>")
      if existing_term
        options.delete(:uri) # We already have this.
        connection.set_node_properties(existing_term, options)
        return existing_term
      end
      begin
        term_node = connection.create_node(options)
        # ^ I got a "Could not set property "uri", class Neography::PropertyValueException here.
        connection.set_label(term_node, "Term")
        # ^ I got a Neography::BadInputException here saying I couldn't add a label. In that case, the URI included
        # UTF-8 chars, so I think I fixed it by causing all URIs to be escaped...
        count = Rails.cache.read("trait_bank/terms_count") || 0
        Rails.cache.write("trait_bank/terms_count", count + 1)
      rescue => e
        debugger
        raise e
      end
      term_node
    end

    def child_has_parent(curi, puri)
      cterm = term(curi)
      pterm = term(puri)
      child_term_has_parent_term(cterm, pterm)
    end

    def child_term_has_parent_term(cterm, pterm)
      relate(:parent_term, cterm, pterm)
    end


    def term(uri)
      @terms ||= {}
      return @terms[uri] if @terms.key?(uri)
      res = query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '""')}" }) RETURN term})
      return nil unless res["data"] && res["data"].first
      @terms[uri] = res["data"].first.first
    end

    def update_term(opts)
      sets = []
      sets += %i(name definition attribution comment sections).map do |field|
        opts[field] = "" if opts[field].nil?
        "term.#{field} = '#{opts[field].gsub("'", "''")}'"
      end
      sets += %i(is_hidden_from_glossary is_hidden_from_glossary).map do |field|
        "term.#{field} = #{opts[field] ? 'true' : 'false'}"
      end
      q = "MATCH (term:Term { uri: '#{opts[:uri]}' }) SET #{sets.join(', ')} RETURN term"
      res = query(q)
      raise ActiveRecord::RecordNotFound if res.nil?
      res["data"].first.first.symbolize_keys
    end

    def term_as_hash(uri)
      return nil if uri.nil? # Important for param-management!
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
