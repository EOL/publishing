class TraitBank
  class Stats
    CheckResult = Struct.new(:valid, :reason)

    class << self
      def term_query_object_counts(query)
        check_tq_for_object_counts(query)
        count_query_helper(query)
      end

      def term_query_taxon_counts(query)
        check_tq_for_taxon_counts(query)
        count_query_helper(query)
      end

      def count_query_helper(query)
        filter = query.filters.first
        count = query.taxa? ? "distinct page" : "*"

        qs = "MATCH #{TraitBank.page_match(query, "page", "")},\n"\
          "(page)-[#{TraitBank::TRAIT_RELS}]->(trait:Trait)-[:predicate]->(:Term)-[#{TraitBank.parent_terms}]->(:Term{uri: '#{filter.pred_uri}'}),\n"\
          "(trait)-[:object_term]->(obj_child:Term),\n"\
          "(obj_child)-[#{TraitBank.parent_terms}]->(obj:Term)\n"\
          "WITH obj, count(#{count}) AS count\n"\
          "RETURN obj, count\n"\
          "ORDER BY count DESC"
        results = TraitBank.query(qs)
        TraitBank.results_to_hashes(results, "obj")
      end

      def check_common(query)
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

      def check_query_valid_for_object_counts(query)
        if !query.record?
          CheckResult.new(false, "result_type must be record")
        else
          check_common(query)
        end
      end

      def check_query_valid_for_taxon_counts(query)
        if !query.taxa?
          CheckResult.new(false, "result_type must be taxa")
        else
          check_common(query)
        end
      end

      private
      def check_tq_for_object_counts(query)
        result = check_query_valid_for_object_counts(query)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end

      def check_tq_for_taxon_counts(query)
        result = check_query_valid_for_taxon_counts(query)

        if !result.valid
          raise TypeError.new(result.reason)
        end
      end
    end
  end
end

