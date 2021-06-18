# Contains language/locale-agnostic methods used for constructing summaries
# TODO: Rename! e.g. LanguagesShared or something
class PageDecorator
  class BriefSummary
    module Shared
      ResultTerm = Struct.new(:predicate, :term, :source, :toggle_selector)
      Result = Struct.new(:sentence, :terms)

      # NOTE: Landmarks on staging = {"no_landmark"=>0, "minimal"=>1, "abbreviated"=>2, "extended"=>3, "full"=>4} For P.
      # lotor, there's no "full", the "extended" is Tetropoda, "abbreviated" is Carnivora, "minimal" is Mammalia. JR
      # believes this is usually a Class, but for different types of life, different ranks may make more sense.

      # A1: Use the landmark with value 1 that is the closest ancestor of the species. Use the English vernacular name, if
      # available, else use the canonical.
      def a1
        return @a1_link if @a1_link
        @a1 ||= @page.ancestors.reverse.find { |a| a && a.minimal? }
        return nil if @a1.nil?
        a1_name = @a1.page&.vernacular&.string || @a1.vernacular
        # Vernacular sometimes lists things (e.g.: "wasps, bees, and ants"), and that doesn't work. Fix:
        a1_name = nil if a1_name&.match(' and ')
        a1_name ||= @a1.canonical
        @a1_link = @a1.page ? view.link_to(a1_name, @a1.page) : a1_name
        # A1: There will be nodes in the dynamic hierarchy that will be flagged as A1 taxa. If there are vernacularNames
        # associated with the page of such a taxon, use the preferred vernacularName.  If not use the scientificName from
        # dynamic hierarchy. If the name starts with a vowel, it should be preceded by an, if not it should be preceded by
        # a.
      end

      # A2: Use the name of the family (i.e., not a landmark taxon) of the species. Use the English vernacular name, if
      # available, else use the canonical. -- Complication: some family vernaculars have the word "family" in then, e.g.,
      # Rosaceae is the rose family. In that case, the vernacular would make for a very awkward sentence. It would be great
      # if we could implement a rule, use the English vernacular, if available, unless it has the string "family" in it.
      def a2
        return @a2_link if @a2_link
        return nil if a2_node.nil?
        a2_name = a2_node.page&.vernacular(locale: Locale.english)&.string || a2_node.vernacular(locale: Locale.english)
        a2_name = nil if a2_name && a2_name =~ /family/i
        a2_name = nil if a2_name && a2_name =~ / and /i
        a2_name ||= a2_node.canonical_form
        @a2_link = a2_node.page ? view.link_to(a2_name, a2_node.page) : a2_name
      end

      def a2_node
        @a2_node ||= @page.ancestors.reverse.compact.find { |a| Rank.family_ids.include?(a.rank_id) }
      end

      # If the species has a value for measurement type http://purl.obolibrary.org/obo/GAZ_00000071, insert a Distribution
      # Sentence:  "It is found in [G1]."
      def g1
        @g1 ||= values_to_sentence([TermNode.find_by(uri: 'http://purl.obolibrary.org/obo/GAZ_00000071')])
      end

      def add_sentence(options = {})
        sentence = nil

        begin
          sentence = yield
        rescue BadTraitError => e
          Rails.logger.warn(e.message)
        end

        if sentence.present?
          @sentences << sentence
        end
      end

      def is_above_family?
        @page.native_node.present? &&
        @page.native_node.any_landmark? &&
        @page.rank.present? &&
        @page.rank.treat_as &&
        Rank.treat_as[@page.rank.treat_as] < Rank.treat_as[:r_family]
      end

      # Iterate over all growth habit objects and get the first for which
      # GrowthHabitGroup.match returns a result, or nil if none do. The result
      # of this operation is cached.
      def growth_habit_matches
        @growth_habit_matches ||= GrowthHabitGroup.match_all(@page.traits_for_predicate(TermNode.find_by_alias('growth_habit')))
      end

      def reproduction_matches
        @reproduction_matches ||= ReproductionGroupMatcher.match_all(@page.traits_for_predicate(TermNode.find_by_alias('reproduction')))
      end
      
      # ...has a value with parent http://purl.obolibrary.org/obo/ENVO_00000447 for measurement type
      # http://eol.org/schema/terms/Habitat
      def is_it_marine?
        habitat_term = TermNode.find_by_alias('habitat')
        @page.has_data_for_predicate(
          habitat_term,
          with_object_term: TermNode.find_by_alias('marine')
        ) &&
        !@page.has_data_for_predicate(
          habitat_term,
          with_object_term: TermNode.find_by_alias('terrestrial')
        )
      end

      def freshwater_trait
        @freshwater_trait ||= @page.first_trait_for_object_terms([TermNode.find_by_alias('freshwater')])
      end

      def is_species?
        is_rank?('r_species')
      end

      def is_family?
        is_rank?('r_family')
      end

      def is_genus?
        is_rank?('r_genus')
      end

      def below_family?
        @page.rank&.treat_as.present? && Rank.treat_as[@page.rank.treat_as] > Rank.treat_as[:r_family]
      end

      def genus_or_below?
        @page.rank&.treat_as.present? && Rank.treat_as[@page.rank.treat_as] >= Rank.treat_as[:r_genus]
      end

      # NOTE: the secondary clause here is quite... expensive. I recommend we remove it, or if we keep it, preload ranks.
      # NOTE: Because species is a reasonable default for many resources, I would caution against *trusting* a rank of
      # species for *any* old resource. You have been warned.
      def is_rank?(rank)
        if @page.rank
          @page.rank.treat_as == rank
        # else
        #   @page.nodes.any? { |n| n.rank&.treat_as == rank }
        end
      end

      def term_tag(label, predicate, term, trait_source = nil)
        toggle_id = term_toggle_id

        @terms << ResultTerm.new(
          predicate,
          term,
          trait_source,
          "##{toggle_id}"
        )
        view.content_tag(:span, label, class: ["a", "term-info-a"], id: toggle_id)
      end

      # Term can be a predicate or an object term. If predicate is nil, term is treated in the view
      # as a predicate; otherwise, it's treated as an object term.
      def term_sentence_part(format_str, label, predicate, term, source = nil)
        sprintf(
          format_str,
          term_tag(label, predicate, term, source)
        )
      end

      def trait_sentence_part(format_str, trait, options = {})
        return '' if trait.nil?

        if trait.object_page
          association_sentence_part(format_str, trait.object_page)
        elsif trait.predicate && trait.object_term
          name = trait.object_term.name
          name = name.pluralize if options[:pluralize]
          predicate = trait.predicate
          obj = trait.object_term

          term_sentence_part(
            format_str,
            name,
            predicate,
            obj
          )
        elsif trait.literal
          sprintf(format_str, trait.literal)
        else
          raise BadTraitError.new("Undisplayable trait: #{trait.id}")
        end
      end

      def association_sentence_part(format_str, object_page)
        object_page_part = if object_page.nil?
                             Rails.logger.warn("Missing associated page for auto-generated text")
                             "(page not found)"
                           else
                             view.link_to(object_page.short_name(Locale.english).html_safe, object_page)
                           end
        sprintf(format_str, object_page_part)
      end

      def full_name_clause
        if @page.vernacular.present?
          "#{@page.canonical} (#{@page.vernacular.string.titlecase})"
        else
          name_clause
        end
      end

      def name_clause
        @name_clause ||= @page.vernacular_or_canonical
      end

      def add_above_family_group_sentence
        treat_as = @page.rank&.treat_as || 'group'

        if a1.present?
          add_sentence do
            I18n.t("brief_sumamry.above_family_group.#{treat_as}", name1: full_name_clause, name2: a1)
          end
        end
      end

      def add_family_sentence
        add_sentence do
          "#{full_name_clause} is a family of #{a1}."
        end
      end

      def result
        add_sentences
        Result.new(@sentences.join(' '), @terms)
      end
    end
  end
end
