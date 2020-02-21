class TraitBank
  class Stats
    CheckResult = Struct.new(:valid, :reason)

    class << self
      def obj_counts(query)
        check_tq_for_counts(query)
        filter = query.filters.first
        count = query.taxa? ? "distinct page" : "*"

        # Where clause filters for top-level terms or their direct children only
        # WITH DISTINCT is necessary to filter out multiple paths from obj_child to obj (I think?)
        qs = "MATCH #{TraitBank.page_match(query, "page", "")},\n"\
          "(page)-[#{TraitBank::TRAIT_RELS}]->(trait:Trait),\n"\
          "(trait)-[:predicate]->(:Term)-[#{TraitBank.parent_terms}]->(:Term{uri: '#{filter.pred_uri}'}),\n"\
          "(trait)-[:object_term]->(obj_child:Term),\n"\
          "(obj_child)-[#{TraitBank.parent_terms}]->(obj:Term)\n"\
          "WHERE NOT (obj)-[:parent_term*2..]->(:Term)\n"\
          "WITH DISTINCT page, trait, obj\n"\
          "WITH obj, count(#{count}) AS count\n"\
          "RETURN obj, count\n"\
          "ORDER BY count DESC"
        results = TraitBank.query(qs)
        TraitBank.results_to_hashes(results, "obj")
      end

      def check_query_valid_for_counts(query)
        if query.predicate_filters.length != 1
          return CheckResult.new(false, "query must have a single predicate filter")
        end

        uri = query.predicate_filters.first.pred_uri
        predicate = TermNode.find(uri)

        if predicate.nil?
          return CheckResult.new(false, "failed to retrieve a Term with uri #{uri}")
        end

        if predicate.type != "measurement"
          return CheckResult.new(false, "predicate type must be 'measurement'")
        end

        if query.object_term_filters.any?
          return CheckResult.new(false, "query must not have any object term filters")
        end

        if query.numeric_filters.any?
          return CheckResult.new(false, "query must not have any numeric filters")
        end
        
        if query.range_filters.any?
          return CheckResult.new(false, "query must not have any range filters")
        end

        CheckResult.new(true, nil)
      end

      private
      def check_tq_for_counts(query)
        result = check_query_valid_for_counts(query)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end
    end
  end
end

