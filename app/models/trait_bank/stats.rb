class TraitBank
  module Stats
    CheckResult = Struct.new(:valid, :reason) do
      def valid?
        valid
      end

      def self.invalid(reason)
        self.new(false, reason)
      end

      def self.valid
        self.new(true, nil)
      end
    end

    RECORD_THRESHOLD = 20_000
    MIN_RECORDS_FOR_HIST = 4
    OBJ_COUNT_LIMIT_PAD = 5

    class << self
      delegate :log, to: TraitBank::Logger

      def obj_counts(query, limit)
        raise_if_query_invalid_for_counts(query)

        key = "trait_bank/stats/obj_counts/v3/limit_#{limit}/#{query.to_cache_key}" # increment version number when changing query semantics

        Rails.cache.fetch(key) do
          params = {}
          q = if query.taxa?
                obj_counts_query_for_taxa(query, params)
              else
                obj_counts_query_for_records(query, params)
              end
          q.concat("\nLIMIT #{limit + OBJ_COUNT_LIMIT_PAD}")
          results = TraitBank.query(q, params)
          filter_identical_count_ancestors(TraitBank.results_to_hashes(results, "obj"), limit)
        end
      end


      # XXX: this isn't very performant, but the assumption is that that the filtering case is rare
      def filter_identical_count_ancestors(results, limit)
        grouped_results = results.group_by { |result| result[:count] }

        objs_to_filter = []
        grouped_results.each do |_, results_for_count|
          next if results_for_count.length == 1
          results_for_count.each do |result|
            results_for_count.each do |other_result|
              next if result == other_result
              obj = result[:obj][:uri]
              other_obj = other_result[:obj][:uri]
              objs_to_filter << obj if TraitBank::Term.term_descendant_of_other?(other_obj, obj)
            end
          end
        end

        filtered = results.reject { |r| objs_to_filter.include?(r[:obj][:uri]) }
        filtered[0..limit]
      end

      # Returns:
      # bi: bucket index
      # bw: bucket width
      # c: count of records/pages in bucket
      # u: units term
      def histogram(query, record_count)
        raise_if_query_invalid_for_histogram(query, record_count)

        key = "trait_bank/stats/histogram/v3/#{query.to_cache_key}" # increment version number when changing query
        Rails.cache.fetch(key) do
          params = {}
          trait_match_part = TraitBank.term_record_search_matches(query, params, trait_var: "t")
          count = query.record? ? "*" : "DISTINCT rec.page"
          buckets = [Math.sqrt(record_count), 20].min.ceil

          TraitBank.query(%Q[
            #{trait_match_part}
            WITH page, toFloat(t.normal_measurement) AS m
            WITH collect({ page: page, val: m }) as recs, max(m) AS max, min(m) AS min
            WITH recs, max, min, max - min AS range
            WITH recs, #{self.num_fn_for_range("max", "ceil")} AS max,
            #{self.num_fn_for_range("min", "floor")} AS min
            WITH recs, max, min, max - min AS range
            WITH recs, max, min, CASE WHEN range < .001 THEN 1 ELSE (
            #{self.num_fn_for_range("range", "ceil", "/ #{buckets}")}
            ) END AS bw
            UNWIND recs as rec
            WITH rec, min, bw, floor((rec.val - min) / bw) AS bi
            WITH rec, min, bw, CASE WHEN bi = #{buckets} THEN bi - 1 ELSE bi END as bi
            WITH min, bi, bw, count(#{count}) AS c
            RETURN min, bi, bw, c
            ORDER BY bi ASC
          ], params)
        end
      end

      def num_fn_for_range(var, fn, add_op = nil)
        base_case  = add_op.nil? ?
          "#{fn}(#{var})" :
          "#{fn}(#{var} #{add_op})"

        %Q(
          CASE WHEN #{num_fn_for_range_case(0.002, 10000, fn, var, add_op)} ELSE (
            CASE WHEN #{num_fn_for_range_case(0.02, 1000, fn, var, add_op)} ELSE (
              CASE WHEN #{num_fn_for_range_case(0.2, 100, fn, var, add_op)} ELSE (
                CASE WHEN #{num_fn_for_range_case(2, 10, fn, var, add_op)} ELSE (
                  #{base_case}
                ) END
              ) END
            ) END
          ) END
        )
      end

      def num_fn_for_range_case(cutoff, coef, fn, var, add_op)
        fn_part = add_op.nil? ?
          "#{fn}(#{var} * #{coef}) / #{coef}" :
          "#{fn}((#{var} * #{coef}) #{add_op}) / #{coef}"

        "range < #{cutoff} THEN #{fn_part}"
      end

      def sankey_data(term_query)
        Rails.cache.fetch("trait_bank/stats/#{term_query.to_cache_key}") do
          parts = []
          params = {}

          # labels for aggregated lists of the form collect({ obj: ..., tgt_obj: ... }) AS <label>
          collected_obj_pairs_vars = []

          # pairs of hashes { obj: <obj_var>, tgt_obj: <tgt_obj_var> } where <obj_var> is the matched trait
          # object for a filter and <tgt_obj> is the (parent) node matching the filter's object uri. If a given
          # filter doesn't have an object_term, tgt_obj won't be present.
          obj_var_pairs = []

          add_sankey_match_part(term_query, parts, params, collected_obj_pairs_vars, obj_var_pairs)
          obj_pair_vars = sankey_add_unwind_obj_pairs_part(parts, collected_obj_pairs_vars, obj_var_pairs)
          sankey_add_collect_pages_per_objs_part(parts, obj_var_pairs, obj_pair_vars)
          anc_obj_vars = sankey_add_match_anc_objs_part(parts, obj_var_pairs)
          sankey_add_anc_obj_case_part(parts, obj_var_pairs, anc_obj_vars)
          sankey_add_final_agg_and_return_parts(parts, anc_obj_vars)

          TraitBank.results_to_hashes(
            TraitBank.query(parts.join("\n"), params), 
            'key'
          )
        end
      end

      def check_query_valid_for_histogram(query, count)
        if count < MIN_RECORDS_FOR_HIST
          return CheckResult.invalid("record count doesn't meet minimum of #{MIN_RECORDS_FOR_HIST}")
        end

        if query.predicate_filters.length != 1
          return CheckResult.invalid("query must have a single predicate filter")
        end

        pred_uri = query.predicate_filters.first.pred_uri
        pred_result = check_predicate(pred_uri)
        return pred_result if !pred_result.valid?

        if query.object_term_filters.any?
          return CheckResult.invalid("query must not have any object term filters")
        end

        if !query.filters.first.units_for_pred?
          return CheckResult.invalid("query predicate does not have numerical values")
        end

        if !TraitBank::Term.any_direct_records_for_pred?(pred_uri)
          return CheckResult.invalid("predicate does not have any directly associated records")
        end

        CheckResult.valid
      end


      def check_query_valid_for_counts(query)
        if query.filters.length != 1
          return CheckResult.invalid("query must have a single filter")
        end

        filter = query.filters.first
        pred_uri = filter.pred_uri

        if pred_uri.present?
          pred_result = check_predicate(pred_uri)
          return pred_result if !pred_result.valid?

          if filter.units_for_pred?
            return CheckResult.invalid("query predicate has numerical values")
          end

          #if (
          #    query.clade.present? &&
          #    record_count > RECORD_THRESHOLD
          #)
          #  return CheckResult.invalid("count exceeds threshold for search with clade")
          #end
        end

        if filter.numeric?
          return CheckResult.invalid("query must not be numeric")
        end

        CheckResult.valid
      end

      def check_query_valid_for_sankey(query)
        if query.record?
          return CheckResult.invalid("query must be for taxa")
        end

        if query.filters.length < 2
          return CheckResult.invalid("query must have multiple filters")
        end

        query.filters.each do |f|
          if f.obj_clade.present?
            return CheckResult.invalid("query can't have a filter with an object clade")
          end
        end

        CheckResult.valid
      end

      private

      def obj_counts_query_for_records(query, params)
        obj_var = "child_obj"
        trait_var = "trait"
        anc_var = "anc"
        match_part = TraitBank.term_record_search_matches(query, params, always_match_obj: true, obj_var: obj_var, trait_var: trait_var)

        %Q(
          #{match_part}
          WITH #{obj_var}, count(distinct #{trait_var}) AS trait_count
          #{count_query_anc_obj_match(query, obj_var, anc_var, params)}
          WITH DISTINCT #{anc_var}, #{obj_var}, trait_count
          WITH #{anc_var} AS obj, sum(trait_count) AS count
          RETURN obj, count
          ORDER BY count DESC
        )
      end

      def obj_counts_query_for_taxa(query, params)
        obj_var = "child_obj"
        anc_var = "anc"
        match_part = TraitBank.term_page_search_matches(query, params, always_match_obj: true, obj_var: obj_var)

        %Q(
          #{match_part}
          WITH #{obj_var}, collect(distinct page) as pages
          #{count_query_anc_obj_match(query, obj_var, anc_var, params)}
          WITH #{anc_var} AS obj, collect(pages) as list_of_lists_of_pages
          WITH obj, reduce(output = [], p in list_of_lists_of_pages | output + p) AS pages
          UNWIND pages AS page
          WITH obj, count(distinct page) AS count
          RETURN obj, count
          ORDER BY count DESC
        )
      end

      def count_query_anc_obj_match(query, obj_var, anc_var, params)
        result = "MATCH (#{obj_var})-[#{TraitBank.parent_terms}]->(#{anc_var}:Term)"
        filter = query.filters.first

        if filter.object_term?
          result.concat("-[#{TraitBank.parent_terms}]->(:Term { uri: $count_query_obj })")
          params[:count_query_obj] = filter.obj_uri
        end

        result.concat("\nWHERE #{anc_var}.is_hidden_from_select = false")

        result
      end

      # Usual trait search MATCHes, collect tgt_obj and obj nodes for each filter/page
      def add_sankey_match_part(term_query, query_parts, params, collected_obj_pairs_vars, obj_var_pairs)
        query_parts << TraitBank.term_search_matches_helper(
          term_query, 
          params, 
          always_match_obj: true, 
          with_tgt_vars: true
        ) do |i, filter, trait_var, pred_var, tgt_pred_var, obj_var, tgt_obj_var|
          with = "WITH page, "
          collected_obj_pairs_var = nil
          tgt_obj_var = filter.object_term? ? tgt_obj_var : nil

          if i < term_query.filters.length - 1
            collected_obj_pairs_var = obj_var + "_pairs"
            collect = filter.object_term? ? 
              "{ obj: #{obj_var}, tgt_obj: #{tgt_obj_var} }" :
              "{ obj: #{obj_var} }"
            with.concat("collect(#{collect}) AS #{collected_obj_pairs_var}")
          else
            with.concat("#{obj_var}")
            with.concat(", #{tgt_obj_var}") if filter.object_term?
          end

          if collected_obj_pairs_vars.any?
            with.concat(", #{collected_obj_pairs_vars.join(", ")}")
          end

          collected_obj_pairs_vars << collected_obj_pairs_var if collected_obj_pairs_var
          obj_var_pairs << { obj: obj_var, tgt_obj: tgt_obj_var }

          with
        end
      end

      # Add query part to unwind lists of objects collected in first part of query, and return Array of variables referring to the unwound object pairs (e.g., <label> in 'UNWIND <pairs> AS <label>')
      def sankey_add_unwind_obj_pairs_part(query_parts, collected_obj_pairs_vars, obj_var_pairs)
        obj_pair_vars = []

        query_parts << collected_obj_pairs_vars.map.with_index do |var, i|
          pair_var = "#{obj_var_pairs[i][:obj]}_pair"
          obj_pair_vars << pair_var
          "UNWIND #{var} AS #{pair_var}"
        end.join("\n")

        obj_pair_vars
      end

      def sankey_add_collect_pages_per_objs_part(query_parts, obj_var_pairs, obj_pair_vars)
        # Expand { tgt_obj: ..., obj: ... } pairs (labeled by labels in obj_pair_vars) back into separate variables using labels in obj_var_pairs.
        obj_var_parts = obj_pair_vars.map.with_index do |pair, i|
          part = "#{pair}.obj AS #{obj_var_pairs[i][:obj]}"

          if obj_var_pairs[i][:tgt_obj]
            part.concat(", #{pair}.tgt_obj AS #{obj_var_pairs[i][:tgt_obj]}")
          end

          part
        end
        
        # We didn't collect the pairs for the last filter (they're already 'unwound', so to speak), so just pass them through
        obj_var_parts << obj_var_pairs[-1][:obj]
        obj_var_parts << obj_var_pairs[-1][:tgt_obj] if obj_var_pairs[-1][:tgt_obj]

        # Collect pages per distinct combination of objects
        query_parts << "WITH #{obj_var_parts.join(", ")}, collect(DISTINCT page) AS pages"
      end

      # Add query part to match the ancestor object Terms to return from the query, and return Array of the labels of said objects
      def sankey_add_match_anc_objs_part(query_parts, obj_var_pairs)
        anc_obj_vars = Array.new(obj_var_pairs.length)

        # For each row, get the appropriate ancestor(s) of each object. In the case of a filter with an object term, we want the
        # ancestor(s) that is a child of the object term; in the case of a predicate-only filter, it is the term(s) w/o a parent.

        anc_matches = obj_var_pairs.map.with_index do |pair, i|
          anc_obj_var = "anc_obj#{i}"
          anc_obj_vars[i] = anc_obj_var

          if pair[:tgt_obj]
            # NOTE: using a WHERE here, rather than a single match that also expresses the where condition, makes a significant difference in query performance.
            # The latter approach results in a query plan that gets all of the children of the tgt_obj (many in the case of a broad Term like Northern Hemisphere),
            # then does the other half of the query and joins the results. Using a WHERE clause resutls in a SemiApply which filters the results of the OPTIONAL MATCH
            # one by one using the WHERE clause test. tl;dr: WHERE results in going "up" the term hierarchy, and never down, which is better.
            "OPTIONAL MATCH (#{pair[:obj]})-[#{TraitBank.parent_terms}]->(#{anc_obj_var}:Term)\nWHERE (#{anc_obj_var})-[:parent_term]->(#{pair[:tgt_obj]})"
          else
            "OPTIONAL MATCH (#{pair[:obj]})-[#{TraitBank.parent_terms}]->(#{anc_obj_var}:Term)\nWHERE NOT (#{anc_obj_var})-[:parent_term|:synonym_of]->(:Term)"
          end
        end

        query_parts << anc_matches.join("\n")

        anc_obj_vars
      end

      def sankey_add_anc_obj_case_part(query_parts, obj_var_pairs, anc_obj_vars)
        # include original terms if they're the direct object (or synonym of direct object) of their matching traits
        obj_cases = obj_var_pairs.map.with_index do |pair, i|
          if pair[:tgt_obj]
            "CASE WHEN #{anc_obj_vars[i]} IS NULL THEN #{pair[:tgt_obj]} ELSE #{anc_obj_vars[i]} END AS #{anc_obj_vars[i]}"
          else
            anc_obj_vars[i]
          end
        end
        query_parts << "WITH #{obj_cases.join(", ")}, pages"
      end

      def sankey_add_final_agg_and_return_parts(query_parts, anc_obj_vars)
        # re-group pages per combination of ancestor terms
        query_parts << "UNWIND pages AS page"
        query_parts << "WITH #{anc_obj_vars.join(", ")}, collect(DISTINCT page.page_id) AS page_ids"

        # row id, named columns for return
        query_parts << "WITH #{anc_obj_vars.map { |v| "#{v}.uri" }.join(" + '|' + ")} AS key, #{anc_obj_vars.map { |v| "#{v}.name AS #{v}_name, #{v}.uri AS #{v}_uri" }.join(", ")}, page_ids"
        query_parts << "RETURN key, #{anc_obj_vars.map { |v| "#{v}_uri, #{v}_name" }.join(", ")}, page_ids"
        query_parts << "ORDER BY size(page_ids) DESC"
      end


      def raise_if_query_invalid_for_counts(query)
        result = check_query_valid_for_counts(query)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end

      def raise_if_query_invalid_for_histogram(query, count)
        result = check_query_valid_for_histogram(query, count)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end

      def raise_if_query_invalid_for_sankey(query)
        result = check_query_valid_for_sankey(query)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end

      def check_predicate(uri)
        predicate = uri && TermNode.find(uri)

        if predicate.nil?
          return CheckResult.invalid("failed to retrieve a Term with uri #{uri}")
        end

        if predicate.type != "measurement"
          return CheckResult.invalid("predicate type must be 'measurement'")
        end

        CheckResult.valid
      end
    end
  end
end
