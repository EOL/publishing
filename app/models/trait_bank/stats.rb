class TraitBank
  class Stats
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

    PRED_URIS_FOR_THRESHOLD = Set.new([
      Eol::Uris.habitat_includes,
      Eol::Uris.geographic_distribution,
      Eol::Uris.trophic_level,
      Eol::Uris.ecoregion
    ])
    RECORD_THRESHOLD = 20_000
    MIN_RECORDS_FOR_HIST = 4

    class << self
      def obj_counts(query, record_count, limit)
        check_tq_for_counts(query, record_count)
        filter = query.filters.first
        count = query.taxa? ? "distinct page" : "*"
        key = "trait_bank/stats/obj_counts/v1/limit_#{limit}/#{query.to_cache_key}" # increment version number when changing query

        Rails.cache.fetch(key) do
          Rails.logger.info("TraitBank::Stats.object_counts -- running query for key #{key}")
          # Where clause filters for top-level terms or their direct children only
          # WITH DISTINCT is necessary to filter out multiple paths from obj_child to obj (I think?)
          # "WHERE NOT (obj)-[:parent_term*2..]->(:Term)\n"\ removed
          qs = "MATCH #{TraitBank.page_match(query, "page", "")},\n"\
            "(page)-[#{TraitBank::TRAIT_RELS}]->(trait:Trait),\n"\
            "(trait)-[:predicate]->(:Term)-[#{TraitBank.parent_terms}]->(:Term{uri: '#{filter.pred_uri}'}),\n"\
            "(trait)-[:object_term]->(:Term)-[#{TraitBank.parent_terms}]->(obj:Term)\n"\
            "WITH DISTINCT page, trait, obj\n"\
            "WHERE obj.is_hidden_from_select = false\n"\
            "WITH obj, count(#{count}) AS count\n"\
            "RETURN obj, count\n"\
            "ORDER BY count DESC\n"\
            "LIMIT #{limit}"
          results = TraitBank.query(qs)
          TraitBank.results_to_hashes(results, "obj")
        end
      end

      # Returns:
      # bi: bucket index
      # bw: bucket width
      # c: count of records/pages in bucket
      # u: units term
      def histogram(query, record_count)
        check_tq_for_histogram(query, record_count)
        filter = query.filters.first

        wheres = ["t.normal_measurement IS NOT NULL"]
        wheres << "toFloat(t.normal_measurement) >= #{filter.num_val1}" if filter.num_val1.present?
        wheres << "toFloat(t.normal_measurement) < #{filter.num_val2}" if filter.num_val2.present?

        count = query.record? ? "*" : "DISTINCT rec.page"

        buckets = [Math.sqrt(record_count), 20].min.ceil
        qs = "MATCH #{TraitBank.page_match(query, "page", "")},\n"\
          "(tgt_p:Term{ uri: '#{filter.pred_uri}'}),\n"\
          "(page)-[#{TraitBank::TRAIT_RELS}]->(t:Trait)-[:predicate]->(:Term)-[#{TraitBank.parent_terms}]->(tgt_p),\n"\
          "(t)-[:normal_units_term]->(u:Term)\n"\
          "WITH page, u, toFloat(t.normal_measurement) AS m\n"\
          "WHERE #{wheres.join(" AND ")}\n"\
          "WITH u, collect({ page: page, val: m }) as recs, max(m) AS max, min(m) AS min\n"\
          "WITH u, recs, max, min, max - min AS range\n"\
          "WITH u, recs, range, CASE WHEN range < 2 THEN ceil(max * 10) / 10 ELSE ceil(max) END AS max,"\
          "CASE WHEN range < 2 THEN floor(min * 10) / 10 ELSE floor(min) END AS min\n"\
          "WITH u, recs, max, min, CASE WHEN range = 0 THEN 1 ELSE (\n"\
          "CASE WHEN range < 2 THEN ceil(range * 10 / #{buckets}) / 10 ELSE ceil(range / #{buckets}) END\n"\
          ") END AS bw\n"\
          "UNWIND recs as rec\n"\
          "WITH rec, u, min, bw, floor((rec.val - min) / bw) AS bi \n"\
          "WITH u, min, bi, bw, count(#{count}) AS c\n"\
          "WITH u, collect({ min: min, bi: bi, bw: bw, c: c}) as units_rows\n"\
          "ORDER BY reduce(total = 0, r in units_rows | total + r.c) DESC\n"\
          "LIMIT 1\n"\
          "UNWIND units_rows as r\n"\
          "WITH u, r.min as min, r.bi as bi, r.bw as bw, r.c as c\n"\
          "RETURN u, min, bi, bw, c\n"\
          "ORDER BY bi ASC"
        TraitBank.query(qs)
      end
      #  "WITH ms, init_max, min, bw, (init_max - min) % bw as rem\n"\
      #  "WITH ms, min, bw, CASE WHEN rem = 0 THEN init_max ELSE init_max + bw - rem END AS max\n"\

      def check_measurement_query_common(query)
        if query.predicate_filters.length != 1
          return CheckResult.invalid("query must have a single predicate filter")
        end

        uri = query.predicate_filters.first.pred_uri
        predicate = TermNode.find(uri)

        if predicate.nil?
          return CheckResult.invalid("failed to retrieve a Term with uri #{uri}")
        end

        if predicate.type != "measurement"
          return CheckResult.invalid("predicate type must be 'measurement'")
        end

        if query.object_term_filters.any?
          return CheckResult.invalid("query must not have any object term filters")
        end

        CheckResult.valid
      end

      def check_query_valid_for_histogram(query, record_count)
        if record_count < MIN_RECORDS_FOR_HIST
          return CheckResult.invalid("record count doesn't meet minimum of #{MIN_RECORDS_FOR_HIST}")
        end

        common_result = check_measurement_query_common(query)
        return common_result if !common_result.valid?

        if !query.filters.first.units_for_pred?
          return CheckResult.invalid("query predicate does not have numerical values")
        end

        if !TraitBank::Terms.any_direct_records_for_pred?(query.filters.first.pred_uri)
          return CheckResult.invalid("predicate does not have any directly associated records")
        end

        CheckResult.valid
      end


      def check_query_valid_for_counts(query, record_count)
        common_result = check_measurement_query_common(query)
        return common_result if !common_result.valid?

        if query.filters.first.units_for_pred?
          return CheckResult.invalid("query predicate has numerical values")
        end

        if query.numeric_filters.any?
          return CheckResult.invalid("query must not have any numeric filters")
        end
        
        if query.range_filters.any?
          return CheckResult.invalid("query must not have any range filters")
        end

        if (
            query.clade.present? &&
            PRED_URIS_FOR_THRESHOLD.include?(uri) &&
            record_count > RECORD_THRESHOLD
        )
          return CheckResult.invalid("count exceeds threshold for uri")
        end

        CheckResult.valid
      end

      private
      def check_tq_for_counts(query, record_count)
        result = check_query_valid_for_counts(query, record_count)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end

      def check_tq_for_histogram(query, record_count)
        result = check_query_valid_for_histogram(query, record_count)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end
    end
  end
end

