# Abstraction between our traits and the implementation of their storage. ATM, we use neo4j. THE SCHEMA FOR TRAITS CAN
# BE FOUND IN db/neo4j_schema.md ...please read that file before attempting to understand this one. :D
require 'neo4j/core/cypher_session/adaptors/bolt'

class TraitBank
  TRAIT_RELS = ":trait|:inferred_trait"
  GROUP_META_VALUE_URIS = Set.new([
    Eol::Uris.stops_at
  ])

  class << self
    delegate :log, :warn, :log_error, to: TraitBank::Logger

    def connection
      @connection ||= Neography::Rest.new(Rails.configuration.traitbank_url)
    end

    def ping
      begin
        connection.list_indexes
      rescue Excon::Error::Socket => e
        return false
      end
      true
    end

    def query(q, params={})
      start = Time.now
      results = nil
      q.sub(/\A\s+/, "")
      begin
        results = connection.execute_query(q, params)
        stop = Time.now
      rescue Excon::Error::Socket => e
        log_error("Connection refused on query: #{q}")
        sleep(0.1)
        results = connection.execute_query(q, params)
      rescue Excon::Error::Timeout => e
        log_error("Timed out on query: #{q}")
        sleep(1)
        results = connection.execute_query(q, params)
      ensure
        q.gsub!(/ +([A-Z ]+)/, "\n\\1") if q.size > 80 && q !~ /\n/
        log(">>TB TraitBank [neography] (#{stop ? stop - start : "F"}):\n#{q}")
      end
      results
    end

    def quote(string)
      return string if string.is_a?(Numeric) || string =~ /\A[-+]?[0-9,]*\.?[0-9]+\Z/
      %Q{"#{string.gsub(/"/, "\\\"")}"}
    end

    def count
      res = query("MATCH (trait:Trait)<-[#{TRAIT_RELS}]-(page:Page) WITH count(trait) as count RETURN count")
      res["data"] ? res["data"].first.first : false
    end

    def count_by_resource(id)
      Rails.cache.fetch("trait_bank/count_by_resource/#{id}") do
        count_by_resource_no_cache(id)
      end
    end

    def count_by_resource_no_cache(id)
      res = query(
        "MATCH (res:Resource { resource_id: #{id} })<-[:supplier]-(trait:Trait)<-[#{TRAIT_RELS}]-(page:Page) "\
        "USING INDEX res:Resource(resource_id) "\
        "WITH count(trait) as count "\
        "RETURN count")
      res["data"] ? res["data"].first.first : false
    end

    def count_by_resource_and_page(resource_id, page_id)
      Rails.cache.fetch("trait_bank/count_by_resource/#{resource_id}/pages/#{page_id}") do
        res = query(
          "MATCH (res:Resource { resource_id: #{resource_id} })<-[:supplier]-(trait:Trait)<-[#{TRAIT_RELS}]-(page:Page { page_id: #{page_id} }) "\
          "USING INDEX res:Resource(resource_id) USING INDEX page:Page(page_id) "\
          "WITH count(trait) as count "\
          "RETURN count")
        res["data"] ? res["data"].first.first : false
      end
    end

    def count_by_page(page_id)
      Rails.cache.fetch("trait_bank/count_by_page/#{page_id}", expires_in: 1.day) do
        res = query(
          "MATCH (trait:Trait)<-[#{TRAIT_RELS}]-(page:Page { page_id: #{page_id} }) "\
          "WITH count(trait) as count "\
          "RETURN count")
        res["data"] ? res["data"].first.first : false
      end
    end

    def predicate_count_by_page(page_id)
      Rails.cache.fetch("trait_bank/predicate_count_by_page/#{page_id}", expires_in: 1.day) do
        res = query(
          "MATCH (page:Page { page_id: #{page_id} }) -[#{TRAIT_RELS}]->"\
          "(trait:Trait)-[:predicate]->(term:Term) "\
          "WITH count(distinct(term.uri)) AS count "\
          "RETURN count")
        res["data"] ? res["data"].first.first : 0
      end
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

    def limit_and_skip_clause(page = 1, per = 50)
      # I don't know why the default values don't work, but:
      page ||= 1
      per ||= 50
      skip = (page.to_i - 1) * per.to_i
      add = " LIMIT #{per}"
      add = " SKIP #{skip}#{add}" if skip > 0
      add
    end

    # TODO: add association to the sort... normal_measurement comes after literal, so it will be ignored
    def order_clause_array(options)
      options[:sort] ||= ""
      options[:sort_dir] ||= ""
      sorts =
        if options[:by]
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

    def by_trait_and_page(input, page_id, page = 1, per = 200)
      id = input.is_a?(Hash) ? input[:id] : input # Handle both raw IDs *and* actual trait hashes.
      page_id_part = page_id.nil? ? "" : "{ page_id: #{page_id} }"
      trait_rel = page_id.nil? ? ":trait" : TRAIT_RELS
      q = "MATCH (page:Page#{page_id_part})"\
          "-[#{trait_rel}]->(trait:Trait { eol_pk: '#{id.gsub("'", "''")}' })"\
          "-[:supplier]->(resource:Resource) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term) "\
          "OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term) "\
          "OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term) "\
          "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
          "OPTIONAL MATCH (trait)-[data]->(meta:MetaData)-[:predicate]->(meta_predicate:Term) "\
          "OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term) "\
          "OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term) "\
          "RETURN resource, trait, predicate, object_term, units, sex_term, lifestage_term, statistical_method_term, "\
            "meta, meta_predicate, meta_units_term, meta_object_term, page " # \
          # "ORDER BY LOWER(meta_predicate.name)"
      q += limit_and_skip_clause(page, per)
      res = query(q)
      build_trait_array(res, group_meta_by_predicate: true)
    end

    def data_dump_trait(pk)
      id = pk.gsub("'", "''")
      query(%{
        MATCH (trait:Trait { eol_pk: '#{id}' })-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)
        OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term)
        OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term)
        OPTIONAL MATCH (meta)-[:sex_term]->(sex_term:Term)
        OPTIONAL MATCH (meta)-[:lifestage_term]->(lifestage_term:Term)
        OPTIONAL MATCH (meta)-[:statistical_method_term]->(statistical_method_term:Term)
        RETURN meta.eol_pk, trait.eol_pk, meta_predicate.uri, meta.literal, meta.measurement, meta_object_term.uri,
          meta_units_term.uri, sex_term.uri, lifestage_term.uri, statistical_method_term.uri, meta.source
      })
    end

    def by_page(page_id, page = 1, per = 100)
      Rails.cache.fetch("trait_bank/by_page/#{page_id}", expires_in: 1.day) do
        q = "MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)"\
            "-[:supplier]->(resource:Resource) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term) "\
          "OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term) "\
          "OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term) "\
          "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
          "RETURN resource, trait, predicate, object_term, units, sex_term, lifestage_term, statistical_method_term"

        # q += order_clause(by: ["LOWER(predicate.name)", "LOWER(object_term.name)",
        #   "LOWER(trait.literal)", "trait.normal_measurement"])
        q += limit_and_skip_clause(page, per)
        res = query(q)
        build_trait_array(res)
      end
    end

    def page_traits_by_pred(page_id, options = {})
      limit = options[:limit] || 5 # limit is per predicate
      key = "trait_bank/page_traits_by_pred/no_synonyms/#{page_id}/limit_#{limit}"
      add_hash_to_key(key, options)

      Rails.cache.fetch(key) do
        res = query(%Q(
          MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(:Term)-[:synonym_of*0..]->(predicate:Term),
          (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])})
          WHERE NOT (predicate)-[:synonym_of]->(:Term)
          WITH predicate, collect(DISTINCT trait)[0..#{limit}] as traits, count(DISTINCT trait) AS trait_count, resource
          UNWIND traits as trait
          OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
          OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
          OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
          OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
          OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
          RETURN resource, trait, predicate, object_term, units, sex_term, lifestage_term, statistical_method_term, trait_count
        ))

        build_trait_array(res)
      end
    end

    def page_trait_predicates(page_id, options = {})
      key = "trait_bank/page_trait_predicates/#{page_id}"
      add_hash_to_key(key, options)
      Rails.cache.fetch(key) do
        res = query(%Q(
          MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(:Term)-[:synonym_of*0..]->(predicate:Term),
          (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])})
          WHERE NOT (predicate)-[:synonym_of]->(:Term)
          WITH DISTINCT predicate
          RETURN predicate.uri, predicate.name, predicate.definition, predicate.comment, predicate.attribution
        ))
        flat_results_to_hashes(res, id_col_label: "predicate.uri").collect do |hash|
          hash[:predicate]
        end
      end
    end

    def page_trait_resource_ids(page_id, options = {})
      key = "trait_bank/page_trait_resource_ids/#{page_id}"
      add_hash_to_key(key, options)

      Rails.cache.fetch(key) do
        predicate_filter_part = options[:pred_uri] ? "-[#{parent_terms}]->(:Term{ uri: '#{options[:pred_uri]}' })" : ""

        res = query(%Q(
          MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term)#{predicate_filter_part},
          (trait)-[:supplier]->(resource:Resource)
          RETURN DISTINCT resource.resource_id
        ))

        res["data"].flatten
      end
    end

    def all_page_traits_for_pred(page_id, pred_uri, options = {})
      key = "trait_bank/all_page_traits_for_pred/include_synonyms/#{page_id}/#{pred_uri}"
      add_hash_to_key(key, options)

      Rails.cache.fetch(key) do
        res = query(%Q(
          MATCH (:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term)-[:synonym_of*0..]->(:Term{ uri: '#{pred_uri}'}),
          (trait)-[:supplier]->(resource:Resource#{resource_filter_part(options[:resource_id])})
          OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
          OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
          OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
          OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
          OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
          RETURN resource, trait, predicate, object_term, units, sex_term, lifestage_term, statistical_method_term
        ))

        build_trait_array(res)
      end
    end

    def data_dump_page(page_id)
      query(%{
        MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:supplier]->(resource:Resource),
          (trait:Trait)-[:predicate]->(predicate:Term)
        OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
        OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
        OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
        OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
        OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
        OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units:Term)
        RETURN trait.eol_pk, page.page_id, trait.scientific_name, trait.resource_pk, predicate.uri, sex_term.uri,
          lifestage_term.uri, statistical_method_term.uri, trait.source, trait.object_page_id,
          trait.target_scientific_name, object_term.uri, trait.literal, trait.measurement, units.uri,
          trait.normal_measurement, normal_units.uri, resource.resource_id
      })
    end

    def key_data(page_id, limit)
      Rails.cache.fetch("trait_bank/key_data/#{page_id}/v2/limit_#{limit}", expires_in: 1.day) do
        # predicate.is_hidden_from_overview <> true seems wrong but I had weird errors with NOT "" on my machine -- mvitale
        q = "MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
          "WHERE predicate.is_hidden_from_overview <> true AND (NOT (trait)-[:object_term]->(:Term) OR (trait)-[:object_term]->(:Term{ is_hidden_from_overview: false })) "\
          "WITH predicate, head(collect(trait)) as trait "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term) "\
          "OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term) "\
          "OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term) "\
          "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
          "RETURN trait, predicate, object_term, units, sex_term, lifestage_term, statistical_method_term "\
          "LIMIT #{limit}"

        res = query(q)
        build_trait_array(res).collect { |r| [r[:predicate], r] }.to_h
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
        batch = TraitBank.term_search(term_query, options.merge(page: page))[:data]
        batch_found = batch.size
        found += batch_found
        yield(batch)
        page += 1
      end
    end

    # Call this with an option of cache: false if you want to skip caching the RESULTS. Result counts will ALWAYS be
    # cached.
    def term_search(term_query, options={})
      key = term_query.to_cache_key
      if options[:count]
        key = "trait_bank/term_search/counts/#{key}"
        if Rails.cache.exist?(key)
          count = Rails.cache.read(key)
          log("&& TS USING cached count: #{key} = #{count}")
          return count
        end
      else
        add_hash_to_key(key, options)
      end
      if options.key?(:cache) && !options[:cache]
        term_search_uncached(term_query, key, options)
      else
        Rails.cache.fetch("term_search/v2/#{key}") do
          term_search_uncached(term_query, key, options)
        end
      end
    end

    def term_search_uncached(term_query, key, options)
      limit_and_skip = options[:page] ? limit_and_skip_clause(options[:page], options[:per]) : ""

      q = if term_query.record?
        term_record_search(term_query, limit_and_skip, options)
      else
        term_page_search(term_query, limit_and_skip, options)
      end

      res = query(q[:query], q[:params])

      log("&& TS SAVING Cache: #{key}")
      if options[:count]
        raise "&& TS Lost key" if key.blank?

        counts = TraitBank::TermSearchCounts.new(res)
        Rails.cache.write(key, counts, expires_in: 1.day)
        log("&& TS SAVING Cached counts: #{key} = #{counts}")
        counts
      else
        log("RESULT COUNT #{key}: #{res["data"] ? res["data"].length : "unknown"} raw")
        data = if options[:id_only]
                 res["data"]&.flatten
               else
                 trait_array_options = { key: key, flat_results: true }
                 build_trait_array(res, trait_array_options)
               end

        { data: data, raw_query: q[:query], params: q[:params], raw_res: res }
      end
    end

    def parent_terms
      @parent_terms ||= ":parent_term|:synonym_of*0.."
    end

    def term_filter_where_term_part(anc_term_label, child_term_label, term_uri, term_type, params, gathered_terms)
      gathered_term = gathered_terms.find { |t| t.type == term_type }

      if gathered_term
        "#{child_term_label} IN #{gathered_term.list_label}"  
      else
        term_uri_param = "#{anc_term_label}_uri"
        params[term_uri_param] = term_uri
        "#{anc_term_label}.uri = $#{term_uri_param}"
      end
    end

    def term_filter_where_obj_clade_part(obj_clade_var, child_obj_clade_var, obj_clade_id, params, gathered_terms)
      gathered_term = gathered_terms.find { |t| t.type == :object_clade }

      if gathered_term
        "#{child_obj_clade_var} IN #{gathered_term.list_label}"
      else
        obj_clade_id_param = "#{obj_clade_var}_page_id"
        params[obj_clade_id_param] = obj_clade_id
        "#{obj_clade_var}.page_id = $#{obj_clade_id_param}"
      end
    end


    def term_filter_where(
      filter, 
      trait_var, 
      pred_var, 
      child_pred_var, 
      obj_var, 
      child_obj_var, 
      obj_clade_var,
      child_obj_clade_var,
      params, 
      gathered_terms = []
    )
      parts = []
      term_condition = []

      if filter.predicate?
        term_condition << term_filter_where_term_part(pred_var, child_pred_var, filter.pred_uri, :predicate, params, gathered_terms)
      end

      if filter.object_term?
        term_condition << term_filter_where_term_part(obj_var, child_obj_var, filter.obj_uri, :object_term, params, gathered_terms)
      end

      if filter.obj_clade.present?
        term_condition << term_filter_where_obj_clade_part(obj_clade_var, child_obj_clade_var, filter.obj_clade.id, params, gathered_terms)
      end

      parts << "#{term_condition.join(" AND ")}"

      if filter.numeric?
        conditions = []
        if filter.eq?
          conv_eq_val, conv_units_uri = UnitConversions.convert(filter.num_val1, filter.units_uri)
          eq_param = "#{trait_var}_eq"
          conditions << { op: "=", val: conv_eq_val, param: eq_param }
        else
          if filter.gt? || filter.range?
            conv_gt_val, conv_units_uri1 = UnitConversions.convert(filter.num_val1, filter.units_uri)
            gt_param = "#{trait_var}_gt"
            conditions << { op: ">=", val: conv_gt_val, param: gt_param }
          end

          if filter.lt? || filter.range?
            conv_lt_val, conv_units_uri2 = UnitConversions.convert(filter.num_val2, filter.units_uri)
            lt_param = "#{trait_var}_lt"
            conditions << { op: "<=", val: conv_lt_val, param: lt_param }
          end

          conv_units_uri = conv_units_uri1 || conv_units_uri2
        end

        parts << "("\
        "(#{trait_var}.measurement IS NOT NULL "\
        "#{conditions.map { |c| "AND toFloat(#{trait_var}.measurement) #{c[:op]} $#{c[:param]}" }.join(" ")} "\
        "AND (#{trait_var}:Trait)-[:units_term]->(:Term{ uri: \"#{conv_units_uri}\" })) "\
        "OR "\
        "(#{trait_var}.normal_measurement IS NOT NULL "\
        "#{conditions.map { |c| "AND toFloat(#{trait_var}.normal_measurement) #{c[:op]} $#{c[:param]}" }.join(" ")} "\
        "AND (#{trait_var}:Trait)-[:normal_units_term]->(:Term{ uri: \"#{conv_units_uri}\" }))"\
        ")"
        conditions.each { |c| params[c[:param]] = c[:val] }
      end

      parts.join(" AND ")
    end

    def add_term_filter_meta_match(pred_uri, obj_uri, trait_var, meta_var, matches, params)
      pred_uri_param = "#{meta_var}_pred_uri"
      obj_uri_param = "#{meta_var}_obj_uri"
      match =
        "(#{trait_var})-[:metadata]->(#{meta_var}:MetaData), "\
        "(#{meta_var})-[:predicate]->(:Term)-[#{parent_terms}]->(:Term{ uri: $#{pred_uri_param} }), "\
        "(#{meta_var})-[:object_term]->(:Term)-[#{parent_terms}]->(:Term{ uri: $#{obj_uri_param} })"
      matches << match
      params[pred_uri_param] = pred_uri
      params[obj_uri_param] = obj_uri
    end

    def add_term_filter_meta_matches(filter, trait_var, base_meta_var, matches, params)
      add_term_filter_meta_match(
        Eol::Uris.sex,
        filter.sex_uri,
        trait_var,
        "#{base_meta_var}_sex",
        matches,
        params
      ) if filter.sex_term?

      add_term_filter_meta_match(
        Eol::Uris.lifestage,
        filter.lifestage_uri,
        trait_var,
        "#{base_meta_var}_ls",
        matches,
        params
      ) if filter.lifestage_term?

      add_term_filter_meta_match(
        Eol::Uris.statistical_method,
        filter.statistical_method_uri,
        trait_var,
        "#{base_meta_var}_stat",
        matches,
        params
      ) if filter.statistical_method_term?
    end

    def add_term_filter_resource_match(filter, trait_var, matches, params)
      if filter.resource
        resource_param = "#{trait_var}_resource"
        matches << "(#{trait_var})-[:supplier]->(:Resource{ resource_id: $#{resource_param} })"
        params[resource_param] = filter.resource.id
      end
    end

    def record_search_returns(include_meta)
      returns = %w[
        page.page_id
        trait.eol_pk
        trait.measurement
        trait.object_page_id
        trait.sample_size
        trait.citation
        trait.source
        trait.remarks
        trait.method
        object_term.uri
        object_term.name
        object_term.definition
        object_page.page_id
        predicate.uri
        predicate.name
        predicate.definition
        units.uri
        units.name
        units.definition
        statistical_method_term.uri
        statistical_method_term.name
        statistical_method_term.definition
        sex_term.uri
        sex_term.name
        sex_term.definition
        lifestage_term.uri
        lifestage_term.name
        lifestage_term.definition
        resource.resource_id
      ]

      if include_meta # NOTE: it's necessary to return meta.eol_pk for downstream result processing
        returns.concat(%w[
          meta.eol_pk
          meta_predicate.uri
          meta_predicate.name
          meta_predicate.definition
          meta_units_term.uri
          meta_units_term.name
          meta_units_term.definition
          meta_object_term.uri
          meta_object_term.name
          meta_object_term.definition
          meta_sex_term.uri
          meta_sex_term.name
          meta_sex_term.definition
          meta_lifestage_term.uri
          meta_lifestage_term.name
          meta_lifestage_term.definition
          meta_statistical_method_term.uri
          meta_statistical_method_term.name
          meta_statistical_method_term.definition
        ])
      end

      "RETURN #{returns.join(", ")}"
    end

    def add_clade_match(term_query, gathered_terms, query_parts, params, match_clade_first)
      if term_query.clade_node
        page_match = "MATCH (page:Page)-[:parent*0..]->(anc: Page { page_id: $clade_id })"
        params["clade_id"] = term_query.clade_node.page_id

        if term_query.filters.any?
          if match_clade_first
            page_match_with = "WITH DISTINCT page"
          else
            page_match_with = "WITH collect(DISTINCT page) AS pages"
          end

          add_gathered_terms(page_match_with, gathered_terms)
          page_match.concat("\n#{page_match_with}")
        end

        query_parts << page_match
      end
    end

    def add_clade_where_conditional(clade_matched, filter_index, filter, term_query, query_parts)
      if (
        !clade_matched &&
        term_query.clade && 
        filter_index > 0 &&
        term_query.clade_node.descendant_count < filter.min_distinct_page_count
      )
        query_parts << "WHERE page IN pages"
        true
      end

      false
    end

    def term_record_search(term_query, limit_and_skip, options)
      params = {}

      trait_var = "trait"
      pred_var = "pred"
      match_part = term_record_search_matches(term_query, params, count: options[:count] || false, trait_var: trait_var, pred_var: pred_var)

      last_part = if term_query.filters.length > 1
        if options[:count]
          %Q(
            WITH count(*) AS page_count, sum(trait_count) AS record_count
            RETURN page_count, record_count
          )
        else
          %Q(
            UNWIND trait_rows AS trait_row
            WITH page, trait_row.trait AS trait, trait_row.predicate AS predicate 
            #{record_optional_matches_and_returns(limit_and_skip, options)}
          )
        end
      else
        if options[:count]
          query = %Q(
            WITH count(DISTINCT page) AS page_count, count(DISTINCT #{trait_var}) AS record_count
            RETURN page_count, record_count
          )
        else
          query = %Q(
            WITH DISTINCT page, #{trait_var} AS trait, #{pred_var} AS predicate
            #{record_optional_matches_and_returns(limit_and_skip, options)}
          ) 
        end
      end

      query = "#{match_part}\n#{last_part}"
      { query: query, params: params }
    end

    def record_optional_matches_and_returns(limit_and_skip, options)
      optional_matches = [
        "(trait)-[:object_term]->(object_term:Term)",
        "(trait)-[:object_page]->(object_page:Term)",
        "(trait)-[:units_term]->(units:Term)",
        "(trait)-[:normal_units_term]->(normal_units:Term)",
        "(trait)-[:sex_term]->(sex_term:Term)",
        "(trait)-[:lifestage_term]->(lifestage_term:Term)",
        "(trait)-[:statistical_method_term]->(statistical_method_term:Term)",
        "(trait)-[:supplier]->(resource:Resource)"
      ]
      optional_matches += [
        "(trait)-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)",
        "(meta)-[:units_term]->(meta_units_term:Term)",
        "(meta)-[:object_term]->(meta_object_term:Term)",
        "(meta)-[:sex_term]->(meta_sex_term:Term)",
        "(meta)-[:lifestage_term]->(meta_lifestage_term:Term)",
        "(meta)-[:statistical_method_term]->(meta_statistical_method_term:Term)"
      ] if options[:meta]

      %Q(
        #{limit_and_skip}
        #{optional_matches.map { |match| "OPTIONAL MATCH #{match}" }.join("\n")}
        #{record_search_returns(options[:meta])}
      )
    end

    def trait_rels(include_inferred)
      include_inferred ? TRAIT_RELS : ":trait"
    end
    
    def trait_rels_for_query_type(query)
      trait_rels(query.taxa?)
    end

    def page_match(term_query, page_var, anc_var)
      match = "(#{page_var}:Page)"
      match += "-[:parent*0..]->(#{anc_var}:Page { page_id: #{term_query.clade.id} })" if term_query.clade
      match
    end


    GatheredTerm = Struct.new(:value, :type, :list_label)
    def gather_terms_matches(filters, params, first_filter_gather_all)
      matches = []
      gathered_terms = []

      filters.each_with_index do |filter, i|
        gathered_terms[i] = []

        gather_all = i > 0 || first_filter_gather_all 

        if gather_all || filter.all_fields.length > 1
          fields = gather_all ? filter.all_fields : filter.max_trait_row_count_fields

          fields.each do |field|
            label = "gathered_#{field.type}#{i}"
            list_label = "#{label}s"

            if field.type == :object_clade
              page_id_param = "#{label}_page_id"
              params[page_id_param] = field.value
              match = %Q(
                MATCH (#{label}:Page)-[:parent*0..]->(:Page { page_id: $#{page_id_param} })
                WITH collect(DISTINCT #{label}) AS #{list_label}
              )
            else
              uri_param = "#{label}_uri"
              params[uri_param] = field.value
              match = %Q(
                MATCH (#{label}:Term)-[#{parent_terms}]->(:Term{ uri: $#{uri_param} })
                WITH collect(DISTINCT #{label}) AS #{list_label}
              )
            end


            flattened_gathered_terms = gathered_terms.flatten
            if flattened_gathered_terms.any?
              match += ", #{flattened_gathered_terms.map { |t| t.list_label }.join(", ")}"
            end

            matches << match
            gathered_terms[i] << GatheredTerm.new(field.value, field.type, list_label)
          end
        end
      end

      [matches, gathered_terms]
    end

    def filter_term_match_no_hier(trait_var, term_var, term_type)
      "(#{trait_var})-[:#{term_type}]->(#{term_var}:Term)"
    end

    def filter_term_match(trait_var, anc_term_var, child_term_var, term_type, gathered_terms)
      gathered_term = gathered_terms.find { |t| t.type == term_type }

      if gathered_term
        filter_term_match_no_hier(trait_var, child_term_var, term_type)
      else
        "(#{trait_var})-[:#{term_type}]->(#{child_term_var}:Term)-[#{parent_terms}]->(#{anc_term_var}:Term)"
      end
    end

    def add_gathered_terms(with_query, gathered_terms)
      flattened = gathered_terms.flatten
      if flattened.any?
        with_query.concat(", #{gathered_terms.flatten.map { |t| t.list_label }.join(" ,")}")
      end
    end

    def term_search_matches_helper(term_query, params, options = {})
      filters = term_query.page_count_sorted_filters
      filter_parts = []
      clade_matched = term_query.clade_node && (
        filters.empty? ||
        term_query.clade_node.descendant_count < term_query.page_count_sorted_filters.first.min_distinct_page_count
      )
      gathered_term_matches, gathered_terms = gather_terms_matches(filters, params, clade_matched)
      add_clade_match(term_query, gathered_terms, filter_parts, params, clade_matched)

      filters.each_with_index do |filter, i|
        filter_matches = []
        filter_wheres = []

        trait_var = filters.length == 1 && options[:trait_var] ? options[:trait_var] : "trait#{i}"
        pred_var = "tgt_predicate#{i}"
        child_pred_var = filters.length == 1 && options[:pred_var] ? options[:pred_var] : "predicate#{i}"
        obj_var = "tgt_object#{i}"
        child_obj_var = filters.length == 1 && options[:obj_var] ? options[:obj_var] : "object#{i}"
        base_meta_var = "meta#{i}"
        obj_clade_var = "tgt_obj_clade#{i}"
        child_obj_clade_var = "obj_clade#{i}"
        gathered_terms_for_filter = gathered_terms.shift
        clade_matched ||= add_clade_where_conditional(clade_matched, i, filter, term_query, filter_parts)
        page_node = i == 0 && !clade_matched ? "(page:Page)" : "(page)"

        filter_matches << "#{page_node}-[#{trait_rels_for_query_type(term_query)}]->(#{trait_var}:Trait)"

        if filter.object_term?
          filter_matches << filter_term_match(trait_var, obj_var, child_obj_var, :object_term, gathered_terms_for_filter)
        elsif options[:always_match_obj]
          filter_matches << filter_term_match_no_hier(trait_var, child_obj_var, :object_term)
        end

        if filter.obj_clade.present?
          gathered_clade = gathered_terms_for_filter.find { |t| t.type == :object_clade }

          if gathered_clade
            filter_matches << "(#{trait_var})-[:object_page]->(#{child_obj_clade_var}:Page)"
          else
            filter_matches << "(#{trait_var})-[:object_page]->(#{child_obj_clade_var}:Page)-[:parent*0..]->(#{obj_clade_var}:Page)"
          end
        end

        if filter.predicate?
          filter_matches << filter_term_match(trait_var, pred_var, child_pred_var, :predicate, gathered_terms_for_filter)
        elsif options[:always_match_pred]
          filter_matches << filter_term_match_no_hier(trait_var, child_pred_var, :predicate)
        end

        filter_wheres << term_filter_where(filter, trait_var, pred_var, child_pred_var, obj_var, child_obj_var, obj_clade_var, child_obj_clade_var, params, gathered_terms_for_filter)
        filter_wheres << "page IN pages" if term_query.clade && !clade_matched && i = filters.length - 1
        add_term_filter_meta_matches(filter, trait_var, base_meta_var, filter_matches, params)
        add_term_filter_resource_match(filter, trait_var, filter_matches, params)

        match_where = %Q(
          MATCH #{filter_matches.join(", ")}
          WHERE #{filter_wheres.join(" AND ")}
        )

        with = yield(i, trait_var, child_pred_var)

        if with.present?
          add_gathered_terms(with, gathered_terms)

          if term_query.clade && !clade_matched
            with.concat(", pages")
          end
        end

        if with
          filter_parts << "#{match_where}\n#{with}"
        else
          filter_parts << match_where
        end
      end

      %Q( 
        #{gathered_term_matches.join("\n")}
        #{filter_parts.join("\n")}
      )
    end

    def term_page_search_matches(term_query, params, options = {})
      term_search_matches_helper(term_query, params, options) do |i, trait_var, pred_var|
        if i == term_query.filters.length - 1
          nil
        else
          "WITH DISTINCT page"
        end
      end
    end

    def term_record_search_matches(term_query, params, options = {})
      trait_ag_var = options[:count] ? "trait_count" : "trait_rows"

      term_search_matches_helper(term_query, params, options.merge(always_match_pred: true)) do |i, trait_var, pred_var|
        if term_query.filters.length > 1
          if options[:count]
            trait_ag = "count(DISTINCT #{trait_var})"
          else
            trait_ag = "collect(DISTINCT { trait: #{trait_var}, predicate: #{pred_var}})"
          end

          if i > 0
            trait_ag = "(#{trait_ag} + #{trait_ag_var})"
          end

          "WITH page, #{trait_ag} AS #{trait_ag_var}"
        else
          nil
        end
      end
    end


    def term_page_search(term_query, limit_and_skip, options)
      params = {}
      match_part = term_page_search_matches(term_query, params)
      with_count_clause = options[:count] ? "WITH COUNT(DISTINCT(page)) AS page_count " : ""
      return_clause = if options[:count]
                        "RETURN page_count"
                      else options[:id_only]
                        "RETURN DISTINCT page.page_id"
                      end

      query = %Q(
        #{match_part}
        #{with_count_clause}
        #{return_clause}
        #{limit_and_skip}
      )

      { query: query, params: params }
    end

    def count_pages
      q = "MATCH (page:Page) RETURN COUNT(page)"
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

    # For results where each column is labeled <node_label>.<property>, e.g., "predicate.uri",
    # and the values are all strings or numbers
    def flat_results_to_hashes(results, options = {})
      id_col_label = options[:id_col_label] || "trait.eol_pk"
      id_col = results["columns"].index(id_col_label)
      id_col ||= 0 # If there is no trait column and nothing was specified...
      raise "missing id column #{id_col_label}" if id_col.nil?
      hashes = []
      previous_id = nil
      hash = {}

      results["data"].each do |row|
        row_id = row[id_col]
        raise("Found row with no ID on row: #{row.inspect}") if row_id.nil?

        if row_id != previous_id
          previous_id = row_id
          hashes << hash unless hash.empty?
          hash = {}
        end

        nodes = {}
        results["columns"].each_with_index do |col, i|
          node_label, node_prop = col.split(".")
          raise "unexpected column name -- expect <label>.<prop> format" unless node_label && node_prop

          node_label = node_label.to_sym
          node_prop = node_prop.to_sym
          value = row[i]

          nodes[node_label] ||= {}
          if value.present?
            nodes[node_label][node_prop] = row[i]
          end
        end

        nodes.each do |label, node|
          if hash.has_key?(label)
            if hash[label].is_a?(Array)
              hash[label] << node
            elsif hash[label] != node
              # ...turn it into an array and add the new value.
              hash[label] = [hash[label], node]
            # Note the lack of "else" ... if the value is the same as the last
            # row, we ignore it (assuming it's a duplicate value and another
            # column is changing)
            end
          else
            # See note in results_to_hashes
            if label.to_s =~ /\Ameta/
              hash[label] = [node]
            else
              hash[label] = node unless node.empty?
            end
          end
        end
      end
      hashes << hash unless hash.empty?
      hashes
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
        id_col_val = row[id_col]
        row_id = if id_col_val.is_a? String
                   id_col_val
                 else
                   id_col_val.dig("metadata", "id")
                 end
        raise("Found row with no ID on row: #{row.inspect}") if row_id.nil?
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
    def build_trait_array(results, options={})
      hashes = options[:flat_results] ? flat_results_to_hashes(results) : results_to_hashes(results)
      key = options[:key]
      log("RESULT COUNT #{key}: #{hashes.length} after results_to_hashes") if key
      data = []
      hashes.each do |hash|
        has_trait = hash.keys.include?(:trait)
        hash.merge!(hash[:trait]) if has_trait
        hash[:resource_id] =
          if hash[:resource]
            if hash[:resource].is_a?(Array)
              hash[:resource].first[:resource_id]
            else
              hash[:resource][:resource_id]
            end
          else
            "MISSING"
          end

        if hash[:predicate].is_a?(Array)
          log_error("Trait {#{hash[:trait][:resource_pk]}} from resource #{hash[:resource_id]} has "\
            "#{hash[:predicate].size} predicates")
          hash[:predicate] = hash[:predicate].first
        end

        hash[:object_page_id] ||= hash.dig(:object_page, :page_id)

        # TODO: extract method
        if hash.has_key?(:meta)
          raise "Metadata not returned as an array" unless hash[:meta].is_a?(Array)
          length = hash[:meta].size
          raise "Missing meta column meta_predicate: #{hash.keys}" unless hash.has_key?(:meta_predicate)
          %i[meta_predicate meta_units_term meta_object_term meta_sex_term meta_lifestage_term meta_statistical_method_term].each do |col|
            next unless hash.has_key?(col)
            raise ":#{col} data was not the same size as :meta" unless hash[col].size == length
          end

          process_hash_metadata(hash)
        end
        if has_trait
          hash[:id] = hash[:trait][:eol_pk]
        end
        hashes = replicate_trait_hash_for_pages(hash)
        data = data + hashes
      end
      log("RESULT COUNT #{key}: #{data.length} after build_trait_array") if key
      data
    end

    def process_hash_metadata(hash)
      grouped_value_metas = {}

      hash[:meta].compact!
      hash[:metadata] = []

      unless hash[:meta].empty?
        hash[:meta].each_with_index do |meta, i|
          m_hash = meta
          m_hash[:predicate] = hash[:meta_predicate] && hash[:meta_predicate][i]
          m_hash[:object_term] = hash[:meta_object_term] && hash[:meta_object_term][i]
          m_hash[:sex_term] = hash[:meta_sex_term] && hash[:meta_sex_term][i]
          m_hash[:lifestage_term] = hash[:meta_lifestage_term] && hash[:meta_lifestage_term][i]
          m_hash[:statistical_method_term] = hash[:meta_statistical_method_term] && hash[:meta_statistical_method_term][i]
          m_hash[:units] = hash[:meta_units_term] && hash[:meta_units_term][i]

          uri = m_hash[:predicate]&.[](:uri)
          if GROUP_META_VALUE_URIS.include?(uri)
            if grouped_value_metas[uri].nil?
              m_hash[:combined_measurements] = []
              grouped_value_metas[uri] = m_hash
            end

            measurement = m_hash[:measurement]

            if measurement
              grouped_value_metas[uri][:combined_measurements] << measurement
            end
          else
            hash[:metadata] << m_hash
          end
        end

        grouped_value_metas.each do |_, meta|
          hash[:metadata] << meta
        end
      end
    end

    def replicate_trait_hash_for_pages(hash)
      return [hash] if !hash[:page]

      if !hash[:page]
        hashes = [hash]
      elsif hash[:page].is_a?(Array)
        hashes = hash[:page].collect do |page|
          copy = hash.dup
          copy[:page_id] = page[:page_id]
          copy
        end
      else
        hash[:page_id] = hash[:page][:page_id]
        hashes = [hash]
      end

      hashes
    end

    def resources(traits)
      resources = Resource.where(id: traits.map { |t| t[:resource_id] }.compact.uniq)
      # A little magic to index an array as a hash:
      Hash[ *resources.map { |r| [ r.id, r ] }.flatten ]
    end

    def create_page(id)
      if (page = page_exists?(id))
        return page
      end
      page = connection.create_node(page_id: id)
      connection.set_label(page, "Page")
      page
    end

    def find_resource(id)
      res = query("MATCH (resource:Resource { resource_id: #{id} }) RETURN resource LIMIT 1")
      res["data"] ? res["data"].first : false
    end

    def create_resource(id_param)
      id = id_param.to_i
      return "#{id_param} is not a valid positive integer id!" if
        id_param.is_a?(String) && !id.positive? && id.to_s != id_param
      if (resource = find_resource(id))
        return resource
      end
      resource = connection.create_node(resource_id: id)
      connection.set_label(resource, 'Resource')
      resource
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
          log_error("** ERROR adding a #{how} relationship:\n#{e.message}")
          log_error("** from: #{from}")
          log_error("** to: #{to}")
        rescue Neography::NeographyError => e
          log_error("** ERROR adding a #{how} relationship:\n#{e.message}")
          log_error("** from: #{from}")
          log_error("** to: #{to}")
        rescue Excon::Error::Socket => e
          puts "** TIMEOUT adding relationship"
          log_error("** ERROR adding a #{how} relationship:\n#{e.message}")
          log_error("** from: #{from}")
          log_error("** to: #{to}")
        end
      end
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

    def parse_term(term_options)
      return nil if term_options.nil?
      return term_options if term_options.is_a?(Hash)
      return create_term(term_options)
    end

    def create_term(options)
      if (existing_term = term(options[:uri])) # NO DUPLICATES!
        return existing_term unless options.delete(:force)
      end
      options[:section_ids] = options[:section_ids] ?
        Array(options[:section_ids]).join(",") : ""
      options[:definition] ||= "{definition missing}"
      options[:is_hidden_from_select] = (options.key?(:is_hidden_from_select) && options[:is_hidden_from_select]) ?
        true : false
      options[:definition].gsub!(/\^(\d+)/, "<sup>\\1</sup>")
      if existing_term
        options.delete(:uri) # We already have this.
        begin
          connection.set_node_properties(existing_term, remove_nils(options)) # Cypher is alergic to nils.
        # What I saw was a Neography::PropertyValueException: "null value not supported" ...but I want to catch
        # everything
        rescue => e
          puts "ERROR: failed to update term #{options[:uri]}"
          puts "EXISTING: #{existing_term.inspect}"
          puts "DESIRED: #{options.inspect}"
          puts "You will need to fix this manually. Make note!"
        end
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
        raise e
      end
      term_node
    end

    def remove_nils(hash)
      bad_keys = [] # Never modify a hash as you iterate over it.
      hash.each { |key, val| bad_keys << key if val.nil? }
      # NOTE: removing the key entirely would just skip updating it; we want the value to be empty.
      bad_keys.each { |key| hash[key] = "" }
      hash
    end

    def child_has_parent(curi, puri)
      cterm = term(curi)
      pterm = term(puri)
      raise "missing child" if cterm.nil?
      raise "missing parent" if pterm.nil?
      child_term_has_parent_term(cterm, pterm)
    end

    def is_synonym_of(curi, puri)
      cterm = term(curi)
      pterm = term(puri)
      raise "missing synonym" if cterm.nil?
      raise "missing source of synonym" if pterm.nil?
      relate(:synonym_of, cterm, pterm)
    end

    def child_term_has_parent_term(cterm, pterm)
      relate(:parent_term, cterm, pterm)
    end

    def term(uri)
      return { name: '', uri: '' } if uri.blank?
      @terms ||= {}
      return @terms[uri] if @terms.key?(uri)
      res = query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '""')}" }) RETURN term})
      return nil unless res && res["data"] && res["data"].first
      @terms[uri] = res["data"].first.first
    end

    # Raises ActiveRecord::RecordNotFound if uri is invalid
    def term_record(uri)
      result = term(uri)
      result&.[]("data")&.symbolize_keys
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

    def descendants_of_term(uri)
      terms = query(%{MATCH (term:Term)-[:parent_term|:synonym_of*]->(:Term { uri: "#{uri}" }) RETURN DISTINCT term})
      terms["data"].map { |r| r.first["data"] }
    end

    def term_member_of(uri)
      terms = query(%{MATCH (:Term { uri: "#{uri}" })-[:parent_term|:synonym_of*]->(term:Term) RETURN term})
      terms["data"].map { |r| r.first }
    end

    def term_as_hash(uri)
      return nil if uri.nil? # Important for param-management!
      hash = term(uri)
      raise ActiveRecord::RecordNotFound if hash.nil?
      # NOTE: this step is slightly annoying:
      hash.symbolize_keys
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

    # For data visualization
    def pred_prey_comp_for_page(page)
      eats_string = array_to_qs([Eol::Uris.eats, Eol::Uris.preys_on])
      limit_per_group = 100
      comp_limit = 10

      # Fetch prey of page, predators of page, and predators of prey of page (competitors), limiting the number of results to:
      # 10 prey
      # 10 predators
      # 10 competitors per prey
      qs = "MATCH (source:Page{page_id: #{page.id}}) "\
        "OPTIONAL MATCH (source)-[#{TRAIT_RELS}]->(eats_trait:Trait)-[:predicate]->(eats_term:Term), "\
        "(eats_prey:Page{page_id: eats_trait.object_page_id}) "\
        "WHERE eats_term.uri IN #{eats_string} AND eats_prey.page_id <> source.page_id "\
        "WITH DISTINCT source, eats_prey "\
        "LIMIT #{limit_per_group} "\
        "WITH collect({ group_id: source.page_id, source: source, target: eats_prey, type: 'prey'}) AS prey_rows, source "\
        "OPTIONAL MATCH (pred:Page)-[#{TRAIT_RELS}]->(pred_eats_trait:Trait{object_page_id: source.page_id})-[:predicate]->(pred_eats_term:Term) "\
        "WHERE pred_eats_term.uri IN #{eats_string} AND pred.page_id <> source.page_id "\
        "WITH DISTINCT source, pred, prey_rows "\
        "LIMIT #{limit_per_group} "\
        "WITH collect({ group_id: source.page_id, source: pred, target: source, type: 'predator' }) AS pred_rows, prey_rows, source "\
        "UNWIND prey_rows AS prey_row "\
        "WITH prey_row, pred_rows, prey_rows, source "\
        "OPTIONAL MATCH (comp_eats:Page)-[#{TRAIT_RELS}]->(comp_eats_trait:Trait{object_page_id: prey_row.target.page_id})-[:predicate]->(comp_eats_term:Term) "\
        "WHERE comp_eats_term.uri IN #{eats_string} AND prey_row.target.page_id <> comp_eats.page_id AND comp_eats.page_id <> source.page_id "\
        "WITH prey_row, pred_rows, prey_rows, source, collect(DISTINCT { group_id: prey_row.target.page_id, source: comp_eats, target: prey_row.target, type: 'competitor' })[..#{comp_limit}] AS comp_rows "\
        "UNWIND comp_rows AS comp_row "\
        "WITH DISTINCT pred_rows, prey_rows, collect(comp_row) AS comp_rows "\
        "WITH prey_rows + pred_rows + comp_rows AS all_rows "\
        "UNWIND all_rows AS row "\
        "WITH row WHERE row.group_id IS NOT NULL AND row.source IS NOT NULL AND row.target IS NOT NULL "\
        "WITH row.group_id as group_id, row.source.page_id as source, row.target.page_id as target, row.type as type, { metadata: { id: row.source.page_id + '-' + row.target.page_id } } AS id "\
        "RETURN type, source, target, id "\

      results_to_hashes(query(qs), "id")
    end

    # for word cloud visualization
    def descendant_environments(page)
      max_page_depth = 2
      qs = "MATCH (page:Page)-[:parent*0..#{max_page_depth}]->(:Page{page_id: #{page.id}}),\n"\
        "(page)-[#{TRAIT_RELS}]->(trait:Trait)-[:predicate]->(predicate:Term),\n"\
        "(trait)-[:object_term]->(object_term:Term)\n"\
        "WHERE predicate.uri IN #{array_to_qs([Eol::Uris.habitats_for_wordcloud])}\n"\
        "RETURN trait, predicate, object_term"

      build_trait_array(query(qs))
    end

    # each argument is expected to be an Array of strings
    def array_to_qs(*args)
      result = []
      args.each do |uris|
        result.concat(uris.collect { |uri| "'#{uri}'" })
      end
      "[#{result.join(", ")}]"
    end

    private
    def resource_filter_part(resource_id)
      if resource_id
        "{ resource_id: #{resource_id} }"
      else
        ""
      end
    end

    def add_hash_to_key(key, hash)
      hash.each do |k, v|
        key.concat("/#{k}_#{v}")
      end
    end

  end
end
