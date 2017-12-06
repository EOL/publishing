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
  #     { *resource_pk, *scientific_name, statistical_method, sex, lifestage,
  #       source, measurement, object_page_id, literal, normal_measurement,
  #       normal_units[NOTE: this is a literal STRING, used as symbol in Ruby] }
  # * MetaData: *predicate(Term), object_term(Term), units_term(Term)
  #     { measurement, literal }
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
        q.gsub!(/ +([A-Z ]+)/, "\n\\1") if q.size > 80 && q != /\n/
        Rails.logger.warn(">>TB TraitBank (#{stop ? stop - start : "F"}):\n#{q}")
      end
      results
    end

    def obj_terms_for_pred(pred_uri)
      res = query("MATCH (predicate:Term) <-[:predicate|:parent_term*0..#{CHILD_TERM_DEPTH}]- (trait:Trait) -[:object_term|parent_term*0..#{CHILD_TERM_DEPTH}]-> (object:Term) WHERE predicate.uri = \"#{pred_uri}\" RETURN DISTINCT(object) ORDER BY LOWER(object.name), LOWER(object.uri)")
      res["data"].map do |t|
        t.first["data"].symbolize_keys
      end
    end

    def slurp_traits(resource_id)
      count = slurp_traits_with_count(resource_id)
      count + slurp_traits_with_count(resource_id, true)
    end

    # HERE THERE BE DRAGONS. # Speed improvement using slurp over creating via neography was, for about 3000 traits, a
    # reduction form 4m44s to 14s. ...sooo: worth it. But, yes, the query here is ugly as sin. Sorry. I generalized it a
    # bit... if we really wanted to stay this path (as opposed to moving to something like APOC), we could generalize it
    # further, but this will do for the one-off slurping we have to do for traits. ...Though I might do something
    # similar for terms, later.
    def slurp_traits_with_count(resource_id, meta = false)
      # TODO: csv file location!
      # TODO: (eventually) target_scientific_name: row.target_scientific_name
      header = "USING PERIODIC COMMIT LOAD CSV WITH HEADERS FROM "\
        "'http://localhost:3001/#{'meta_' if meta}traits_#{resource_id}.csv' AS row WITH row"
      plain_traits_clause = 'WHERE row.value_uri IS NULL AND row.units IS NULL'
      valued_traits_clause = 'WHERE row.value_uri IS NOT NULL AND row.units IS NULL'
      measured_traits_clause = 'WHERE row.value_uri IS NULL AND row.units IS NOT NULL'
      # NOTE: there should NEVER be a trait with both a vaule_uri AND a measurement, so we skip that.
      required_merge_clauses =
        meta ?
          <<~META_MERGE_CLAUSES
            MERGE (predicate:Term { uri: row.predicate })
            MERGE (trait:MetaData)
            FOREACH(x IN CASE WHEN row.resource_pk IS NULL THEN [] ELSE [1] END | SET trait.resource_pk = row.resource_pk)
            FOREACH(x IN CASE WHEN row.sex IS NULL THEN [] ELSE [1] END | SET trait.sex = row.sex)
            FOREACH(x IN CASE WHEN row.lifestage IS NULL THEN [] ELSE [1] END | SET trait.lifestage = row.lifestage)
            FOREACH(x IN CASE WHEN row.statistical_method IS NULL THEN [] ELSE [1] END | SET trait.statistical_method = row.statistical_method)
            FOREACH(x IN CASE WHEN row.source IS NULL THEN [] ELSE [1] END | SET trait.source = row.source)
            FOREACH(x IN CASE WHEN row.value_literal IS NULL THEN [] ELSE [1] END | SET trait.value_literal = row.value_literal)
            FOREACH(x IN CASE WHEN row.value_num IS NULL THEN [] ELSE [1] END | SET trait.value_num = row.value_num)
            MERGE (page)-[t_r:trait]->(trait)-[p_r:predicate]->(predicate)
          META_MERGE_CLAUSES
        : <<~MERGE_CLAUSES
            MERGE (resource:Resource { resource_id: #{resource_id} })
            MERGE (page:Page { page_id: toInt(row.page_id) })
            MERGE (predicate:Term { uri: row.predicate })
            MERGE (trait:Trait { scientific_name: row.scientific_name, resource_pk: row.resource_pk })
            FOREACH(x IN CASE WHEN row.sex IS NULL THEN [] ELSE [1] END | SET trait.sex = row.sex)
            FOREACH(x IN CASE WHEN row.lifestage IS NULL THEN [] ELSE [1] END | SET trait.lifestage = row.lifestage)
            FOREACH(x IN CASE WHEN row.statistical_method IS NULL THEN [] ELSE [1] END | SET trait.statistical_method = row.statistical_method)
            FOREACH(x IN CASE WHEN row.source IS NULL THEN [] ELSE [1] END | SET trait.source = row.source)
            FOREACH(x IN CASE WHEN row.target_page_id IS NULL THEN [] ELSE [1] END | SET trait.object_page_id = toInt(row.target_page_id))
            FOREACH(x IN CASE WHEN row.value_literal IS NULL THEN [] ELSE [1] END | SET trait.value_literal = row.value_literal)
            FOREACH(x IN CASE WHEN row.value_num IS NULL THEN [] ELSE [1] END | SET trait.value_num = toInt(row.value_num))
            MERGE (page)-[:trait]->(trait)-[p_r:predicate]->(predicate)
            MERGE (trait)-[:supplier]->(resource)
          MERGE_CLAUSES
      valued_merge_clause = 'MERGE (value:Term { uri: row.value_uri })'
      valued_rel_clause = 'MERGE (trait)-[:object_term]->(value)'
      measured_merge_clause = 'MERGE (units:Term { uri: row.units })'
      measured_rel_clause = 'MERGE (trait)-[:units_term]->(units)'
      return_clause = 'RETURN COUNT(trait)'

      # So, here, we're just building a series of very similar queries (and again for meta, since metadata can have the
      # same associations as traits where this code is concerned). Thus the heavy redundancy:
      res = query([header, plain_traits_clause, required_merge_clauses, return_clause].join(' '))
      new_count = res["data"] ? res["data"].first.first : 0
      res = query([header, valued_traits_clause, required_merge_clauses, valued_merge_clause, valued_rel_clause,
        return_clause].join(' '))
      new_count += res["data"] ? res["data"].first.first : 0
      res = query([header, measured_traits_clause, required_merge_clauses, measured_merge_clause, measured_rel_clause,
        return_clause].join(' '))
      new_count + (res["data"] ? res["data"].first.first : 0)
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
    def batch_term_search(options)
      count = options.delete(:count)
      count ||= TraitBank.term_search(options.merge(count: true))
      found = 0
      batch_found = 1 # Placeholder; will update in query.
      page = 1
      while(found < count && batch_found > 0)
        batch = TraitBank.term_search(options.merge(page: page))
        batch_found = batch.size
        found += batch_found
        yield(batch)
        page += 1
      end
    end

    def term_search(trait_query, options={})

      q = if trait_query.type == "record"
        term_record_search(trait_query, options)
      else
        term_page_search(trait_query, options)
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

    def term_record_search(trait_query, options)
      with_count_clause = options[:count] ? 
                          "WITH COUNT(DISTINCT(trait)) AS count " :
                          ""
      return_clause =     options[:count] ? 
                          "RETURN count" :
                          "RETURN page, trait, predicate, TYPE(info) AS info_type, info_term, resource"

      wheres = trait_query.search_pairs.map do |pair|
        if pair.object
          "(:Term{ uri: \"#{pair.predicate}\" })<-[:predicate|parent_term*0..#{CHILD_TERM_DEPTH}]-"\
                             "(trait)"\
                             "-[:object_term|parent_term*0..#{CHILD_TERM_DEPTH}]->(:Term{ uri: \"#{pair.object}\" })"
        else
          "(trait)-[:predicate|parent_term*0..#{CHILD_TERM_DEPTH}]->(:Term{ uri: \"#{pair.predicate}\" })"
        end
      end

      match_part = 
        "MATCH (page:Page)-[:trait]->(trait:Trait)-[:supplier]->(resource:Resource), "\
        "(trait)-[:predicate]->(predicate:Term)"
      match_part += ", (page)-[:parent*]->(Page { page_id: #{trait_query.clade} })" if trait_query.clade

      optional_match_part = options[:count] ? "" : "OPTIONAL MATCH (trait)-[info:units_term|object_term]->(info_term:Term)"

      where_part = if wheres.empty?
        ""
      else
        "WHERE #{wheres.join(" OR ")}"
      end

      order_part = options[:count] ? "" : "ORDER BY page.name, predicate.name, info_term.name"

      "#{match_part} "\
      "#{where_part} "\
      "#{with_count_clause}"\
      "#{optional_match_part} "\
      "#{return_clause} "\
      "#{order_part} "
    end

    def term_page_search(trait_query, options)
      with_count_clause = options[:count] ?
        "WITH COUNT(DISTINCT(page)) AS count " :
        ""
      return_clause = options[:count] ?
        "RETURN count" :
        "RETURN page"
      page_match = "MATCH (page:Page)"
      page_match += "-[:parent*]->(Page { page_id: #{trait_query.clade} })" if trait_query.clade

      trait_matches = trait_query.search_pairs.each_with_index.map do |pair, i|
        trait_label = "t#{i}"
        match = "MATCH (page) -[:trait]-> (#{trait_label}:Trait), "

        if pair.object
          match += "(:Term{ uri: \"#{pair.predicate}\" })<-[:predicate|parent_term*0..#{CHILD_TERM_DEPTH}]-"\
          "(#{trait_label})"\
          "-[:object_term|parent_term*0..#{CHILD_TERM_DEPTH}]->(:Term{ uri: \"#{pair.object}\" })"
        else
          match += "(#{trait_label})-[:predicate|parent_term*0..#{CHILD_TERM_DEPTH}]->(:Term{ uri: \"#{pair.predicate}\" })"
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

    def by_predicate(uri, options = {})
      term_search(options.merge(predicate: uri))
    end

    def by_predicate_count(uri, options = {})
      term_search(options.merge(predicate: uri, count: true))
    end

    def by_object_term_uri(uri, options = {})
      term_search(options.merge(object_term: uri))
    end

    def by_object_term_count(uri, options = {})\
      term_search(options.merge(object_term: uri, count: true))
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
              debugger if meta.nil?
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
        return existing_term
      end
      options[:section_ids] = options[:section_ids] ?
        Array(options[:section_ids]).join(",") : ""
      options[:definition] ||= "{definition missing}"
      options[:definition].gsub!(/\^(\d+)/, "<sup>\\1</sup>")
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
