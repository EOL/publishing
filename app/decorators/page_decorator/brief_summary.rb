# At the time of writing, this was an implementation of
# https://github.com/EOL/eol_website/issues/5#issuecomment-397708511 and
# https://github.com/EOL/eol_website/issues/5#issuecomment-402848623
require "set"

class PageDecorator
  class BriefSummary
    attr_accessor :view

    class BadTraitError < TypeError; end

    FLOWER_VISITOR_LIMIT = 4
    SUBJ_RESET = 3
    LEAF_PREDICATES = [
      EolTerms.alias_uri('leaf_complexity'),
      EolTerms.alias_uri('leaf_morphology')
    ]

    def initialize(page, view)
      @page = page
      @view = view
      @sentences = []
      @terms = []

      @full_name_used = false
    end

    # NOTE: this will only work for these specific ranks (in the DWH). This is by design (for the time-being). # NOTE: I'm
    # putting species last because it is the most likely to trigger a false-positive. :|
    def english
      if is_above_family?
        above_family
      else
        if !a1.nil?
          if is_family?
            family
          elsif is_genus?
            genus
          elsif is_species?
            species
          end
        end
      end

      landmark_children
      plant_description_sentence
      flower_visitor_sentence
      fixes_nitrogen_sentence
      forms_sentence
      ecosystem_engineering_sentence
      behavioral_sentence

      if is_species?
        lifespan_size_sentence
      end

      reproduction_sentences
      motility_sentence

      Result.new(@sentences.join(' '), @terms)
    end

    private
      LandmarkChildLimit = 3
      Result = Struct.new(:sentence, :terms)
      ResultTerm = Struct.new(:pred_uri, :term, :source, :toggle_selector)

      IUCN_URIS = Set[
        EolTerms.alias_uri('iucn_en'),
        EolTerms.alias_uri('iucn_cr'),
        EolTerms.alias_uri('iucn_ew'),
        EolTerms.alias_uri('iucn_nt'),
        EolTerms.alias_uri('iucn_vu')
      ]

      def add_sentence(options = {})
        use_name = !@full_name_used
        subj = use_name ? name_clause : pronoun_for_rank.capitalize
        are = extinct? ? 'were' : 'are' 
        have = extinct? ? 'had' : 'have'
        sentence = nil

        begin
          sentence = yield(subj, are, have)
        rescue BadTraitError => e
          Rails.logger.warn(e.message)
        end

        if sentence.present?
          if sentence.start_with?("#{subj} ")
            @full_name_used ||= use_name
          end

          @sentences << sentence
        end
      end

      def pronoun_for_rank
        "they"
      end

      def is_above_family?
        @page.native_node.present? &&
        @page.native_node.any_landmark? &&
        @page.rank.present? &&
        @page.rank.treat_as &&
        Rank.treat_as[@page.rank.treat_as] < Rank.treat_as[:r_family]
      end

      def above_family
        if a1.present?
          add_sentence do |subj, _, __|
            "#{subj} is a group of #{a1}." # in this case, the is variable would be 'are', which is not what we want
          end
        end

        desc_info = @page.desc_info
        if desc_info.present?
          add_sentence do |_, __, ___|
            "There #{is_or_are(desc_info.species_count)} #{desc_info.species_count} species of #{@page.name}, in #{view.pluralize(desc_info.genus_count, "genus", "genera")} and #{view.pluralize(desc_info.family_count, "family")}."
          end
        end

        first_appearance_trait = first_trait_for_pred_uri_w_obj(EolTerms.alias_uri('fossil_first'))

        if first_appearance_trait
          add_sentence do |_, __, ___|
            trait_sentence_part("This group has been around since the %s.", first_appearance_trait)
          end
        end
      end

      # [name clause] is a[n] [A1] in the family [A2].
      def species
        # taxonomy sentence:
        # TODO: this assumes perfect coverage of A1 and A2 for all species, which is a bad idea. Have contingencies.
        what = a1
        species_parts = []

        add_sentence do |subj, _, __|
          if match = growth_habit_matches.first_of_type(:species_of_x)
            species_parts << trait_sentence_part(
              "#{subj} is a species of %s",
              match.trait
            )
          elsif match = growth_habit_matches.first_of_type(:species_of_lifecycle_x)
            lifecycle_trait = first_trait_for_pred_uri(EolTerms.alias_uri('lifecycle_habit'))
            if lifecycle_trait
              lifecycle_part = trait_sentence_part("%s", lifecycle_trait)
              species_parts << trait_sentence_part(
                "#{subj} is a species of #{lifecycle_part} %s",
                match.trait
              )
            else # TODO: DRY
              species_parts << trait_sentence_part(
                "#{subj} is a species of %s",
                match.trait
              )
            end
          elsif match = growth_habit_matches.first_of_type(:species_of_x_a1)
            species_parts << trait_sentence_part(
              "#{subj} is a species of %s #{what}",
              match.trait
            )
          else
            species_parts << "#{subj} is a species of #{what}"
          end

          species_parts << " in the family #{a2}" if a2
          species_parts << "."
          species_parts.join("")
        end

        if match = growth_habit_matches.first_of_type(:is_an_x)
          add_sentence do |subj, are, __|
            trait_sentence_part(
              "#{subj} #{are} %ss.",
              match.trait
            )
          end
        end

        if match = growth_habit_matches.first_of_type(:has_an_x_growth_form)
          add_sentence do |subj, are, have|
            trait_sentence_part(
              "#{subj} #{have} #{a_or_an(match.trait)} %s growth form.",
              match.trait
            )
          end
        end

        if !add_extinction_sentence
          conservation_sentence
        end

        # If the species [is extinct], insert an extinction status sentence between the taxonomy sentence
        # and the distribution sentence. extinction status sentence: This species is extinct.

        # If the species [is marine], insert an environment sentence between the taxonomy sentence and the distribution
        # sentence. environment sentence: "It is marine." If the species is both marine and extinct, insert both the
        # extinction status sentence and the environment sentence, with the extinction status sentence first.
        if is_it_marine?
          marine_term = TraitBank::Term.term_as_hash(EolTerms.alias_uri('marine'))
          add_sentence do |subj, are, _|
            term_sentence_part("#{subj} #{are} found in %s.", "marine habitat", EolTerms.alias_uri('habitat'), marine_term)
          end
        elsif freshwater_trait.present?
          add_sentence do |subj, are, _|
            term_sentence_part("#{subj} #{are} associated with %s.", "freshwater habitat", freshwater_trait[:predicate][:uri], freshwater_trait[:object_term])
          end
        end


        native_range_part = values_to_sentence([EolTerms.alias_uri('native_range')])
        if native_range_part.present?
          add_sentence do |subj, are, _|
            "#{subj} #{are} native to #{native_range_part}."
          end
        elsif g1
          add_sentence do |subj, are, _|
            "#{subj} #{are} found in #{g1}."
          end
        end
      end

      # Iterate over all growth habit objects and get the first for which
      # GrowthHabitGroup.match returns a result, or nil if none do. The result
      # of this operation is cached.
      def growth_habit_matches
        @growth_habit_matches ||= GrowthHabitGroup.match_all(traits_for_pred_uris(EolTerms.alias_uri('growth_habit')))
      end

      def reproduction_matches
        @reproduction_matches ||= ReproductionGroupMatcher.match_all(traits_for_pred_uris(EolTerms.alias_uri('reproduction')))
      end

      # [name clause] is a genus in the [A1] family [A2].
      #
      def genus
        family = a2
        if family
          add_sentence do |subj, _, __|
            "#{subj} is a genus of #{a1} in the family #{family}."
          end
        else
          add_sentence do |subj, _, __|
            "#{subj} is a family of #{a1}."
          end
        end
        # We may have a few genera that don't have a family in their ancestry. In those cases, shorten the taxonomy sentence:
        # [name clause] is a genus in the [A1]
      end

      # [name clause] is a family of [A1].
      #
      # This will look a little funny for those families with "family" vernaculars, but I think it's still acceptable, e.g.,
      # Rosaceae (rose family) is a family of plants.
      def family
        add_sentence do |subj, _, __|
          "#{subj} is a family of #{a1}."
        end
      end

      def landmark_children
        children = @page.native_node&.landmark_children(LandmarkChildLimit) || []

        if children.any?
          taxa_links = children.map { |c| view.link_to(c.page.vernacular_or_canonical(Locale.english), c.page) }
          add_sentence do |subj, _, __|
            "#{subj} includes groups like #{to_sentence(taxa_links)}."
          end
        end
      end

      def behavioral_sentence
        circadian = first_trait_for_obj_uris(
          EolTerms.alias_uri('nocturnal'),
          EolTerms.alias_uri('diurnal'),
          EolTerms.alias_uri('crepuscular')
        )
        solitary = first_trait_for_obj_uris(EolTerms.alias_uri('solitary'))
        begin_traits = [solitary, circadian].compact
        trophic = first_trait_for_pred_uri(
          EolTerms.alias_uri('trophic_level'), 
          exclude_values: [EolTerms.alias_uri('variable')]
        )

        add_sentence do |subj, are, _|
          sentence = nil
          trophic_part = trait_sentence_part("%s", trophic, pluralize: true) if trophic

          if begin_traits.any?
            begin_parts = begin_traits.collect do |t|
              trait_sentence_part("%s", t)
            end

            if trophic_part
              sentence = "#{subj} #{are} #{begin_parts.join(", ")} #{trophic_part}."
            else
              sentence = "#{subj} #{are} #{begin_parts.join(" and ")}."
            end
          elsif trophic_part
            sentence = "#{subj} #{are} #{trophic_part}."
          end

          sentence
        end
      end

      def is_a(is, word)
        is
      end

      def lifespan_size_sentence
        lifespan_part = nil
        size_part = nil

        add_sentence do |subj, are, _|
          lifespan_trait = first_trait_for_pred_uri(EolTerms.alias_uri('lifespan'))
          if lifespan_trait
            value = lifespan_trait[:measurement]
            units_name = lifespan_trait.dig(:units, :name)

            if value && units_name
              lifespan_part = "#{are} known to live for #{value} #{units_name}"
            end
          end

          size_traits = traits_for_pred_uris(EolTerms.alias_uri('body_mass'))
          size_traits = traits_for_pred_uris(EolTerms.alias_uri('body_length')) if size_traits.empty?

          if size_traits.any?
            largest_value_trait = nil

            size_traits.each do |trait|
              if trait[:normal_measurement] &&
                 trait[:measurement] &&
                 trait[:units] && (
                 !largest_value_trait ||
                 largest_value_trait[:normal_measurement].to_f < trait[:normal_measurement].to_f
              )
                largest_value_trait = trait
              end
            end

            if largest_value_trait
              can = extinct? ? 'could' : 'can' 
              size_part = "#{can} grow to #{largest_value_trait[:measurement]} #{largest_value_trait[:units][:name]}"
            end
          end

          if lifespan_part || size_part
            "Individuals #{to_sentence([lifespan_part, size_part].compact)}."
          else
            nil
          end
        end
      end

      def reproduction_sentences
        matches = reproduction_matches

        add_sentence do |subj, are, have|
          vpart = if matches.has_type?(:v)
                    v_vals = to_sentence(matches.by_type(:v).collect do |match|
                      trait_sentence_part("%s", match.trait)
                    end)

                    "#{subj} #{have} #{v_vals}"
                  else
                    nil
                  end

          wpart = if matches.has_type?(:w)
                    w_vals = to_sentence(matches.by_type(:w).collect do |match|
                      trait_sentence_part(
                        "%s",
                        match.trait,
                        pluralize: true
                      )
                    end)

                    "#{are} #{w_vals}"
                  else
                    nil
                  end

          if vpart && wpart
            wpart = "they #{wpart}"
            "#{vpart}; #{wpart}."
          elsif vpart
            "#{vpart}."
          elsif wpart
            "#{subj} #{wpart}."
          end
        end

        if matches.has_type?(:y)
          add_sentence do |subj, are, have|
            y_parts = to_sentence(matches.by_type(:y).collect do |match|
              trait_sentence_part("%s #{match.trait[:predicate][:name]}", match.trait)
            end)

            "#{subj} #{have} #{y_parts}."
          end
        end

        if matches.has_type?(:x)
          add_sentence do |_, __, ___|
            x_parts = to_sentence(matches.by_type(:x).collect do |match|
              trait_sentence_part("%s", match.trait)
            end)

            "Reproduction is #{x_parts}."
          end
        end

        if matches.has_type?(:z)
          add_sentence do |subj, are, have|
            z_parts = to_sentence(matches.by_type(:z).collect do |match|
              trait_sentence_part("%s", match.trait)
            end)

            "#{subj} #{have} parental care (#{z_parts})."
          end
        end
      end

      def motility_sentence
        matches = MotilityGroupMatcher.match_all(traits_for_pred_uris(
          EolTerms.alias_uri('motility'),
          EolTerms.alias_uri('locomotion')
        ))

        if matches.has_type?(:c)
          add_sentence do |subj, _, __|
            match = matches.first_of_type(:c)
            trait_sentence_part(
              "#{subj} rely on %s to move around.",
              match.trait
            )
          end
        elsif matches.has_type?(:a) && matches.has_type?(:b)
          add_sentence do |subj, are, _|
            a_match = matches.first_of_type(:a)
            b_match = matches.first_of_type(:b)

            a_part = trait_sentence_part(
              "#{subj} #{are} %s",
              a_match.trait
            )

            trait_sentence_part(
              "#{a_part} %s.",
              b_match.trait,
              pluralize: true
            )
          end
        elsif matches.has_type?(:a)
          add_sentence do |subj, are, _|
            match = matches.first_of_type(:a)

            if @page.animal?
              organism_animal = "animal"
            else
              organism_animal = "organism"
            end

            organism_animal = organism_animal.pluralize

            trait_sentence_part(
              "#{subj} #{are} %s #{organism_animal}.",
              match.trait
            )
          end
        elsif matches.has_type?(:b)
          add_sentence do |subj, are, _|
            match = matches.first_of_type(:b)
            trait_sentence_part(
              "#{subj} #{are} %s.",
              match.trait,
              pluralize: true
            )
          end
        end
      end

      def plant_description_sentence
        leaf_traits = LEAF_PREDICATES.collect { |uri| first_trait_for_pred_uri(uri) }.compact
        flower_trait = first_trait_for_pred_uri(EolTerms.alias_uri('flower_color'))
        fruit_trait = first_trait_for_pred_uri(EolTerms.alias_uri('fruit_type'))
        leaf_part = nil
        flower_part = nil
        fruit_part = nil

        add_sentence do |subj, are, have|
          if leaf_traits.any?
            leaf_parts = leaf_traits.collect { |trait| trait_sentence_part("%s", trait) }
            leaf_part = "#{leaf_parts.join(", ")} leaves"
          end

          if flower_trait
            flower_part = trait_sentence_part("%s flowers", flower_trait)
          end

          if fruit_trait
            fruit_part = trait_sentence_part("%s", fruit_trait)
          end

          parts = [leaf_part, flower_part, fruit_part].compact

          if parts.any?
            "#{subj} #{have} #{to_sentence(parts)}."
          else
            nil
          end
        end
      end

      def flower_visitor_sentence
        page_ids = object_traits_for_pred_uri(EolTerms.alias_uri('visits_flowers_of')).map do |t|
          t[:page_id]
        end.uniq.slice(0, FLOWER_VISITOR_LIMIT)

        if page_ids.any?
          parts = page_ids.collect { |page_id| association_sentence_part("%s", page_id) }
          add_sentence do |_, __, ___|
            "Flowers are visited by #{to_sentence(parts)}."
          end
        end
      end

      def fixes_nitrogen_sentence
        trait = first_trait_for_pred_and_obj(EolTerms.alias_uri('fixes'), EolTerms.alias_uri('nitrogen'))

        if trait
          fixes_part = term_sentence_part("%s", 'fix', nil, trait[:predicate])

          add_sentence do |subj, _, __|
            term_sentence_part(
              "#{subj} #{fixes_part} %s.",
              "nitrogen",
              trait[:predicate][:uri],
              trait[:object_term]
            )
          end
        end
      end

      def forms_sentence 
        # intentionally skip descendants of this term
        forms_traits = (@page.grouped_data[EolTerms.alias_uri('forms')] || []).uniq { |t| t.dig(:object_term, :uri) }

        if forms_traits.any?
          lifestage_traits = forms_traits.find_all do |t|
            t.[](:lifestage_term)&.[](:name)&.present?
          end

          other_traits = forms_traits.reject do |t|
            t.[](:lifestage_term)&.[](:name)&.present?
          end

          if other_traits.any? && lifestage_traits.any?
            sentence_traits = [other_traits.first, lifestage_traits.first]
          elsif other_traits.any?
            sentence_traits = other_traits[0..1]
          elsif lifestage_traits.any?
            sentence_traits = lifestage_traits[0..1]
          end

          sentence_traits.each { |t| add_forms_sentence(t) }
        end
      end

      def add_forms_sentence(trait)
        lifestage = trait.dig(:lifestage_term, :name)
        begin_part = [lifestage, name_clause].compact.join(" ")
        form_part = term_sentence_part("%s", "form", nil, trait[:predicate])

        add_sentence do |_, __, ___|
          trait_sentence_part(
            "#{begin_part} #{form_part} %ss.", #extra s for plural, not a typo
            trait
          )
        end
      end

      def ecosystem_engineering_sentence
        trait = first_trait_for_pred_uri(EolTerms.alias_uri('ecosystem_engineering'))

        if trait
          add_sentence do |subj, are, _|
            obj_name = trait.dig(:object_term, :name)

            if obj_name
              term_sentence_part("#{subj} #{are} %s.", obj_name.pluralize, trait[:predicate][:uri], trait[:object_term])
            else
              nil
            end
          end
        end
      end

      # NOTE: Landmarks on staging = {"no_landmark"=>0, "minimal"=>1, "abbreviated"=>2, "extended"=>3, "full"=>4} For P.
      # lotor, there's no "full", the "extended" is Tetropoda, "abbreviated" is Carnivora, "minimal" is Mammalia. JR
      # believes this is usually a Class, but for different types of life, different ranks may make more sense.

      # A1: Use the landmark with value 1 that is the closest ancestor of the species. Use the English vernacular name, if
      # available, else use the canonical.
      def a1
        return @a1_link if @a1_link
        @a1 ||= @page.ancestors.reverse.find { |a| a && a.minimal? }
        return nil if @a1.nil?
        a1_name = @a1.page&.vernacular(locale: Locale.english)&.string || @a1.vernacular(locale: Locale.english)
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
        @g1 ||= values_to_sentence(['http://purl.obolibrary.org/obo/GAZ_00000071'])
      end

      def name_clause
        if !@full_name_used && @page.vernacular(locale: Locale.english)
          "#{@page.canonical} (#{@page.vernacular(locale: Locale.english).string.titlecase})"
        else
          @name_clause ||= @page.vernacular_or_canonical(Locale.english)
        end
      end

      # ...has a value with parent http://purl.obolibrary.org/obo/ENVO_00000447 for measurement type
      # http://eol.org/schema/terms/Habitat
      def is_it_marine?
        env_terms = gather_terms([EolTerms.alias_uri('habitat')])
        has_data_for_pred_terms(
          env_terms,
          values: [EolTerms.alias_uri('marine')]
        ) &&
        !has_data_for_pred_terms(
          env_terms,
          values: [EolTerms.alias_uri('terrestrial')]
        )
      end

      def freshwater_trait
        @freshwater_trait ||= first_trait_for_obj_uris(EolTerms.alias_uri('freshwater'))
      end

      def has_data(options)
        has_data_for_pred_terms(gather_terms(options[:predicates]), options)
      end

      # This checks for descendants of options[:values] as well, and is
      # preserved as a distinct method for that reason.
      def has_data_for_pred_terms(pred_terms, options)
        recs = []
        pred_terms.each do |term|
          next if @page.grouped_data[term].nil?
          next if @page.grouped_data[term].empty?
          recs += @page.grouped_data[term]
        end
        recs.compact!
        return nil if recs.empty?
        values = gather_terms(options[:values])
        return nil if values.empty?
        return true if recs.any? { |r| r[:object_term] && values.include?(r[:object_term][:uri]) }
        return false
      end

      def traits_for_pred_uris(*pred_uris)
        traits = []
        terms = gather_terms(pred_uris.flatten)

        terms.each do |term|
          traits_for_term = @page.grouped_data[term]
          traits.concat(traits_for_term) if traits_for_term
        end

        traits
      end

      def first_trait_for_pred_uri(pred_uri, options = {})
        exclude_values = options[:exclude_values]
        terms = gather_terms(pred_uri)

        terms.each do |term|
          recs = @page.grouped_data[term]

          if recs && recs.any?
            if exclude_values&.any?
              return recs.find { |r| !exclude_values.include?(r.dig(:object_term, :uri)) }
            else
              return recs.first
            end
          end
        end

        nil
      end

      def first_trait_for_pred_and_obj(pred_uri, obj_uri)
        traits = traits_for_pred_uris(pred_uri)
        traits.find { |t| t[:object_term].present? && t[:object_term][:uri] == obj_uri }
      end

      def first_trait_for_pred_uri_w_obj(pred_uri)
        traits = traits_for_pred_uri(pred_uri)
        traits.find { |t| t[:object_term].present? }
      end

      def traits_for_pred_uri(pred_uri)
        traits_for_pred_uri_helper(pred_uri, @page.grouped_data)
      end

      def object_traits_for_pred_uri(pred_uri)
        traits_for_pred_uri_helper(pred_uri, @page.grouped_object_data)
      end

      def traits_for_pred_uri_helper(pred_uri, grouped_data)
        terms = gather_terms(pred_uri)
        traits = []

        terms.each do |term|
          recs = grouped_data[term]

          if recs
            traits += recs
          end
        end

        traits
      end

      def first_trait_for_obj_uris(*obj_uris)
        obj_uris.each do |uri|
          recs = @page.grouped_data_by_obj_uri[uri]
          return recs.first if recs
        end

        return nil
      end

      def gather_terms(uris)
        terms = []
        Array(uris).each { |uri| terms << uri ; terms += TraitBank::Term.descendants_of_term(uri).map { |t| t['uri'] } }
        terms.compact
      end

      def add_extinction_sentence
        if extinct?
          add_sentence do |_, __, ___|
            term_sentence_part("This species is %s.", "extinct", EolTerms.alias_uri('extinction'), extinct_trait[:object_term])
          end

          true
        else
          false
        end
      end

      def extinct?
        extinct_trait.present? && !extant_trait.present?
      end

      def extinct_trait
        unless @extinct_checked
          @extinct_trait = first_trait_for_obj_uris(EolTerms.alias_uri('iucn_ex'))
          @extinct_checked = true
        end

        @extinct_trait
      end

      def extant_trait
        unless @extant_checked
          @extant_trait = first_trait_for_obj_uris(*gather_terms(EolTerms.alias_uri('extant')))
          @extant_checked = true
        end

        @extant_trait
      end

      # Print all values, separated by commas, with “and” instead of comma before the last item in the list.
      def values_to_sentence(uris)
        values = []
        uris.flat_map { |uri| gather_terms(uri) }.each do |pred_uri|
          next if @page.grouped_data[pred_uri].nil?
          @page.grouped_data[pred_uri].each do |trait|
            if trait.key?(:object_term)
              obj_term = trait[:object_term]
              values << term_tag(obj_term[:name], pred_uri, obj_term)
            else
              values << trait[:literal]
            end
          end
        end
        values.any? ? to_sentence(values.uniq) : nil
      end

      # TODO: it would be nice to make these into a module included by the Page class.
      def is_species?
        is_rank?('r_species')
      end

      def is_family?
        is_rank?('r_family')
      end

      def is_genus?
        is_rank?('r_genus')
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

      def rank_or_clade(node)
        node.rank.try(:name) || "clade"
      end

      # XXX: this does not always work (e.g.: "an unicorn")
      def a_or_an(trait)
        return unless trait[:object_term] && trait[:object_term][:name]
        word = trait[:object_term][:name]
        %w(a e i o u).include?(word[0].downcase) ? "an" : "a"
      end

      def is_or_are(count)
        count == 1 ? "is" : "are"
      end

      def conservation_sentence
        status_recs = ConservationStatus.new(@page).by_provider
        result = []

        result << conservation_sentence_part("as %s by IUCN", status_recs[:iucn]) if status_recs.include?(:iucn) && IUCN_URIS.include?(status_recs[:iucn][:uri])
        result << conservation_sentence_part("as %s by COSEWIC", status_recs[:cosewic]) if status_recs.include?(:cosewic)
        result << conservation_sentence_part("as %s by the US Fish and Wildlife Service", status_recs[:usfw]) if status_recs.include?(:usfw)
        result << conservation_sentence_part("in %s", status_recs[:cites]) if status_recs.include?(:cites)
        if result.any?
          add_sentence do |subj, _, __|
            "#{subj} is listed #{to_sentence(result)}."
          end
        end

      end

      def conservation_sentence_part(fstr, rec)
        term_sentence_part(
          fstr,
          rec[:name],
          EolTerms.alias_uri('conservation_status'),
          rec[:object_term],
          rec[:source]
        )
      end

      def term_toggle_id
        @term_toggle_count ||= -1
        @term_toggle_count += 1
        "brief-summary-toggle-#{@term_toggle_count}"
      end

      def term_tag(label, pred_uri, term, trait_source = nil)
        toggle_id = term_toggle_id

        @terms << ResultTerm.new(
          pred_uri,
          term,
          trait_source,
          "##{toggle_id}"
        )
        view.content_tag(:span, label, class: ["a", "term-info-a"], id: toggle_id)
      end

      # Term can be a predicate or an object term. If pred_uri is nil, term is treated in the view
      # as a predicate; otherwise, it's treated as an object term.
      def term_sentence_part(format_str, label, pred_uri, term, source = nil)
        sprintf(
          format_str,
          term_tag(label, pred_uri, term, source)
        )
      end

      def trait_sentence_part(format_str, trait, options = {})
        return '' if trait.nil?

        if trait[:object_page_id]
          association_sentence_part(format_str, trait[:object_page_id])
        elsif trait[:predicate] && trait[:object_term]
          name = trait[:object_term][:name]
          name = name.pluralize if options[:pluralize]
          pred_uri = trait[:predicate][:uri]
          obj = trait[:object_term]
          term_sentence_part(
            format_str,
            name,
            pred_uri,
            obj
          )
        elsif trait[:literal]
          sprintf(format_str, trait[:literal])
        else
          raise BadTraitError.new("Undisplayable trait: #{trait[:id]}")
        end
      end

      def association_sentence_part(format_str, object_page_id)
        target_page = @page.associated_page(object_page_id)
        target_page_part = if target_page.nil?
                             Rails.logger.warn("Missing associated page for auto-generated text: #{object_page_id}!")
                             "(page not found)"

                           else
                             view.link_to(target_page.name(Locale.english).html_safe, target_page)
                           end
        sprintf(format_str, target_page_part)
      end

      # use instead of Array#to_sentence to use correct locale for text, rather than global I18n.locale
      def to_sentence(a)
        a.to_sentence(locale: :en)
      end
    # end private
  end
end
