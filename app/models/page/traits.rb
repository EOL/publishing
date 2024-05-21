# This represents an attempt to separate out a bunch of trait-fetching methods for Page 
class Page
  module Traits
    include TraitBank::Constants

    # Includes descendants of with_object_term Terms option
    def has_data_for_predicate(predicate, options)
      options = options.merge({ match_object_descendants: true })
      first_trait_for_predicate(predicate, options).present?
    end

    def traits_for_predicate(predicate, options = {})
      traits_for_predicates([predicate], options)
    end

    def traits_for_predicates(predicates, options = {})
      subject_traits_for_predicates_helper(predicates, options)
    end

    def first_trait_for_predicate(predicate, options = {})
      subject_traits_for_predicates_helper(predicate, options.merge(limit: 1))
    end
    
    def object_traits_for_predicate(predicate, options = {})
      traits_for_predicates_helper(
        predicate,
        '(trait:Trait)-[:object_page]->(page)'
      ) 
    end

    def first_trait_for_object_term(object_term, options = {})
      first_trait_for_object_terms([object_term], options)
    end

    def first_trait_for_object_terms(object_terms, options = {})
      return nil unless page_node

      trait_match = options[:match_object_descendants] ? 
        "(trait)-[:object_term]->(child_obj:Term)-[#{PARENT_TERMS}]->(object_term:Term)" :
        '(trait)-[:object_term]->(object_term:Term)'

      exclude_hidden_from_overview = options[:match_object_descendants] && options[:exclude_hidden_from_overview]

      q = page_node.query_as(:page)
        .match('(page)-[:trait|:inferred_trait]->(trait:Trait)')
        .match(trait_match)
        .where('object_term.eol_id': extract_term_arg_ids(object_terms))

      if exclude_hidden_from_overview
        q = q.where('NOT child_obj.is_hidden_from_overview')
      end

      q.return(:trait)
       .limit(1)
       .proxy_as(TraitNode, :trait)
       &.first
    end

    private
    def subject_traits_for_predicates_helper(predicates, options)
      traits_for_predicates_helper(
        predicates,
        '(page)-[:trait|:inferred_trait]->(trait:Trait)',
        options
      )
    end

    def traits_for_predicates_helper(predicates, trait_match, options = {})
      if page_node.nil?
        return options[:limit].present? ? nil : []
      end

      predicate_ids = extract_term_arg_ids(predicates)
      predicate_match = options[:exact_predicate] ? 
        '(parent_predicate:Term)' :
        "(predicate:Term)-[#{PARENT_TERMS}]->(parent_predicate:Term)"

      q = page_node.query_as(:page)
        .match(trait_match)
        .match("(trait)-[:predicate]->#{predicate_match}")
        .where('parent_predicate.eol_id': predicate_ids)

      if !options[:exact_predicate] && options[:exclude_hidden_from_overview]
        q = q.where('NOT predicate.is_hidden_from_overview')
      end

      for_object_term = options[:for_object_term]
      match_object_descendants = for_object_term && options[:match_object_descendants]

      if options[:with_object_term] || for_object_term || match_object_descendants
        object_term_matched = true

        if options[:with_object_term] || (for_object_term && !match_object_descendants)
          q = q.match('(trait)-[:object_term]->(object_term:Term)')
        elsif match_object_descendants
          q = q.match("(trait)-[:object_term]->(object_term:Term)-[#{PARENT_TERMS}]->(parent_object_term:Term)")
        end
      else
        object_term_matched = false
      end

      if for_object_term
        object_term_ids = extract_term_arg_ids(for_object_term)
        target_term = match_object_descendants ? 'parent_object_term' : 'object_term'
        q = q.where("#{target_term}.eol_id": object_term_ids)
      end


      if (options[:exclude_values] || options[:exclude_hidden_from_overview]) && !object_term_matched
        q = q.break.optional_match('(trait)-[:object_term]->(object_term:Term)')
      end

      if options[:exclude_values]
        exclude_ids = extract_term_arg_ids(options[:exclude_values])

        if options[:with_object_term]
          q = q.where_not('object_term.eol_id': exclude_ids)
        else
          q = q
            .where("object_term IS NULL OR NOT object_term.eol_id IN [#{exclude_ids.join(', ')}]")
        end
      end

      if options[:exclude_hidden_from_overview]
        q = q.where('object_term IS NULL OR NOT object_term.is_hidden_from_overview')
      end

      includes = options[:includes] || [:object_term]

      if options[:return_predicate]
        Trait.populate_pk_result(q.return('trait.eol_pk AS trait_pk, parent_predicate AS predicate'), includes: includes)
      elsif options[:limit]
        Trait.wrap_node(
          q.return(:trait)
          .limit(options[:limit])
          .proxy_as(TraitNode, :trait)&.first
        ) #TODO: misleading, it's always a limit of 1 here
      else
        Trait.for_eol_pks(q.pluck('trait.eol_pk'), includes: includes)
      end
    end

    def extract_term_arg_ids(term_arg)
      if term_arg.is_a?(Array)
        term_arg.map { |t| extract_term_arg_ids(t) }
      elsif term_arg.nil?
        nil
      elsif term_arg.respond_to?(:id)
        term_arg.id
      else
        nil
      end
    end

    def pluck_pks(result)
      result.map { |r| r[:trait_pk] }
    end
  end
end
