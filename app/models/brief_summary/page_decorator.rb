class BriefSummary
  class PageDecorator
    delegate_missing_to :@page

    LANDMARK_CHILD_LIMIT = 3

    def initialize(page, view)
      @page = page
      @view = view
    end

    def rank_name
      rank&.human_treat_as
    end

    # we *could* use delegate_missing_to to send all unimplemented methods to page, but 
    # rspec's instance_double can't magically know that that's how this class behaves, so it's
    # better to explicitly define delegating methods. 
    def rank
      @page.rank
    end

    def family_or_above?
      @page.rank&.treat_as.present? &&
      Rank.treat_as[@page.rank.treat_as] <= Rank.treat_as[:r_family]
    end

    def below_family?
      @page.rank&.treat_as.present? && 
      Rank.treat_as[@page.rank.treat_as] > Rank.treat_as[:r_family]
    end

    def above_family?
      @page.rank&.treat_as.present? && 
      Rank.treat_as[@page.rank.treat_as] < Rank.treat_as[:r_family]
    end

    def genus_or_below?
      @page.rank&.treat_as.present? && 
      Rank.treat_as[@page.rank.treat_as] >= Rank.treat_as[:r_genus]
    end

    def traits_for_predicate(predicate)
      @page.traits_for_predicate(predicate)
    end

    def has_native_range?
      native_range_traits.any?
    end

    def native_range_traits
      @native_range_traits ||= traits_for_predicate(TermNode.find_by_alias('native_range'))
    end


    def object_traits_for_predicate(predicate)
      @page.object_traits_for_predicate(predicate)
    end

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
      @a1_link = @a1.page ? @view.link_to(a1_name, @a1.page) : a1_name
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
      a2_name = a2_node.page&.vernacular&.string || a2_node.vernacular
      a2_name = nil if a2_name && a2_name =~ /family/i
      a2_name = nil if a2_name && a2_name =~ / and /i
      a2_name ||= a2_node.canonical
      @a2_link = a2_node.page ? @view.link_to(a2_name, a2_node.page) : a2_name
    end

    def full_name
      if @page.vernacular.present?
        "#{@page.canonical} (#{@page.vernacular.string.titlecase})"
      else
        @page.canonical
      end
    end

    def name
      @name ||= @page.vernacular_or_canonical
    end

    def desc_info
      @page.desc_info
    end

    # Iterate over all growth habit objects and get the first for which
    # GrowthHabitGroup.match returns a result, or nil if none do. The result
    # of this operation is cached.
    def growth_habit_matches
      @growth_habit_matches ||= GrowthHabitGroup.match_all(@page.traits_for_predicate(TermNode.find_by_alias('growth_habit')))
    end

    def extinct?
      extinct_trait.present? && !extant_trait.present?
    end

    def extinct_trait
      unless @extinct_checked
        @extinct_trait = @page.first_trait_for_object_terms([TermNode.find_by_alias('iucn_ex')])
        @extinct_checked = true
      end

      @extinct_trait
    end

    def extant_trait
      unless @extant_checked
        @extant_trait = @page.first_trait_for_object_terms([TermNode.find_by_alias('extant')], match_object_descendants: true)
        @extant_checked = true
      end

      @extant_trait
    end

    def marine?
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

    def freshwater?
      freshwater_trait.present? && !marine?
    end

    def freshwater_trait
      @freshwater_trait ||= @page.first_trait_for_object_terms([TermNode.find_by_alias('freshwater')])
    end

    def first_trait_for_predicate(predicate, options = {})
      @page.first_trait_for_predicate(predicate, options)
    end

    def first_trait_for_object_terms(object_terms, options = {})
      @page.first_trait_for_object_terms(object_terms, options)
    end

    def first_trait_for_object_term(object_term, options = {})
      @page.first_trait_for_object_terms(object_term, options)
    end

    def landmark_children
      @landmark_children ||= (@page.native_node&.landmark_children(LANDMARK_CHILD_LIMIT) || []).map do |node|
        node.page
      end.compact
    end

    def greatest_value_size_trait
      size_traits = @page.traits_for_predicate(TermNode.find_by_alias('body_mass'), includes: [:units_term])
      size_traits = @page.traits_for_predicate(TermNode.find_by_alias('body_length'), includes: [:units_term]) if size_traits.empty?

      greatest_value_trait = nil

      if size_traits.any?
        size_traits.each do |trait|
          if trait.normal_measurement &&
             trait.units_term && (
             !greatest_value_trait ||
             greatest_value_trait.normal_measurement.to_f < trait.normal_measurement.to_f
          )
            greatest_value_trait = trait
          end
        end
      end

      greatest_value_trait
    end

    def leaf_traits
      [
        TermNode.find_by_alias('leaf_complexity'),
        TermNode.find_by_alias('leaf_morphology')
      ].collect { |term| @page.first_trait_for_predicate(term) }.compact
    end

    def form_trait1
      form_traits.any? ? form_traits.first : nil
    end

    def form_trait2
      form_traits.length == 2 ? form_traits.second : nil
    end

    def reproduction_matches
      @reproduction_matches ||= BriefSummary::ReproductionGroupMatcher.match_all(@page.traits_for_predicate(TermNode.find_by_alias('reproduction')))
    end

    def motility_matches
      @motility_matches ||= BriefSummary::MotilityGroupMatcher.match_all(@page.traits_for_predicates([
        TermNode.find_by_alias('motility'),
        TermNode.find_by_alias('locomotion')
      ]))
    end

    def animal?
      @page.animal?
    end

    private
    def form_traits
      unless @form_traits
        # intentionally skip descendants of this term
        traits = @page.traits_for_predicate(
          TermNode.find_by_alias('forms'), 
          exact_predicate: true, 
          includes: [:predicate, :object_term, :lifestage_term]
        ).uniq { |t| t.object_term&.uri }

        lifestage = []        
        other = []

        traits.each do |t|
          if t.lifestage_term&.name.present?
            lifestage << t
          else
            other << t
          end
        end

        if lifestage.any? && other.any?
          @form_traits = [lifestage.first, other.first]
        elsif lifestage.any?
          @form_traits = lifestage[0..1]
        elsif other.any?
          @form_traits = other[0..1]
        else
          @form_traits = []
        end
      end

      @form_traits
    end

    def a2_node
      @a2_node ||= @page.ancestors.reverse.compact.find { |a| Rank.family_ids.include?(a.rank_id) }
    end
  end
end
