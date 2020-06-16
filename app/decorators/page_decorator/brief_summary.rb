# At the time of writing, this was an implementation of
# https://github.com/EOL/eol_website/issues/5#issuecomment-397708511 and
# https://github.com/EOL/eol_website/issues/5#issuecomment-402848623
require "set"

class PageDecorator
  class BriefSummary
    attr_accessor :view

    FLOWER_VISITOR_LIMIT = 4
    SUBJ_RESET = 3

    def initialize(page, view)
      @page = page
      @view = view
      @sentences = []
      @terms = []

      @subj_count = 0
      @full_name_used = false
    end

    # NOTE: this will only work for these specific ranks (in the DWH). This is by design (for the time-being). # NOTE: I'm
    # putting species last because it is the most likely to trigger a false-positive. :|
    def english
      # XXX: needed to prevent alternate-locale behavior from methods like `Array#to_sentence`. DON'T REMOVE THE BIT AT THE END THAT REVERTS I18n.locale!
      prev_locale = I18n.locale
      I18n.locale = :en

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

      if is_species?
        behavioral_sentence
        lifespan_size_sentence
      end

      reproduction_sentences
      motility_sentence

      result = Result.new(@sentences.join(' '), @terms)

      I18n.locale = prev_locale

      result
    end

    private
      LandmarkChildLimit = 3
      Result = Struct.new(:sentence, :terms)
      ResultTerm = Struct.new(:pred_uri, :term, :source, :toggle_selector)

      IUCN_URIS = Set[
        Eol::Uris::Iucn.en,
        Eol::Uris::Iucn.cr,
        Eol::Uris::Iucn.ew,
        Eol::Uris::Iucn.nt,
        Eol::Uris::Iucn.vu
      ]

      def add_sentence(options = {})
        use_name = @subj_count == 0
        subj = use_name ? name_clause : pronoun_for_rank.capitalize
        is = is_species? ? "is" : "are"
        has = is_species? ? "has" : "have"

        sentence = yield(subj, is, has)

        if sentence.present?
          if sentence.start_with?("#{subj} ")
            @full_name_used ||= use_name
            @subj_count = (@subj_count + 1) % SUBJ_RESET
          else
            @subj_count = 0
          end

          @sentences << sentence
        end
      end

      def report_name_used
        @subj_count = 1
      end

      def pronoun_for_rank
        is_species? ? "it" : "they"
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

        first_appearance_trait = first_trait_for_pred_uri_w_obj(Eol::Uris.fossil_first)

        if first_appearance_trait
          trait_sentence_part("This group has been around since the %s.", first_appearance_trait)
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
            lifecycle_trait = first_trait_for_pred_uri(Eol::Uris.lifecycle_habit)
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
          add_sentence do |subj, _, __|
            trait_sentence_part(
              "#{subj} is #{a_or_an(match.trait)} %s.",
              match.trait
            )
          end
        end

        if match = growth_habit_matches.first_of_type(:has_an_x_growth_form)
          add_sentence do |subj, _, __|
            trait_sentence_part(
              "#{subj} has #{a_or_an(match.trait)} %s growth form.",
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
          marine_term = TraitBank.term_as_hash(Eol::Uris.marine)
          add_sentence do |subj, _, __|
            term_sentence_part("#{subj} is found in %s.", "marine habitat", Eol::Uris.habitat_includes, marine_term)
          end
        elsif freshwater_trait.present?
          add_sentence do |subj, _, __|
            term_sentence_part("#{subj} is associated with %s.", "freshwater habitat", freshwater_trait[:predicate][:uri], freshwater_trait[:object_term])
          end
        end

        if native_range_traits.any?
          native_range_part = native_range_traits.collect do |t|
            trait_sentence_part("%s", t)
          end.to_sentence
          add_sentence do |subj, is, _|
            "#{subj} #{is} native to #{native_range_part}."
          end
        elsif g1
          add_sentence do |subj, is, _|
            "#{subj} #{is} found in #{g1}."
          end
        end
      end

      # Iterate over all growth habit objects and get the first for which
      # GrowthHabitGroup.match returns a result, or nil if none do. The result
      # of this operation is cached.
      def growth_habit_matches
        @growth_habit_matches ||= GrowthHabitGroup.match_all(traits_for_pred_uris(Eol::Uris.growth_habit))
      end

      def reproduction_matches
        @reproduction_matches ||= ReproductionGroupMatcher.match_all(traits_for_pred_uris(Eol::Uris.reproduction))
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
          taxa_links = children.map { |c| view.link_to(c.page.vernacular_or_canonical, c.page) }
          add_sentence do |subj, _, __|
            "#{subj} includes groups like #{taxa_links.to_sentence}."
          end
        end
      end

      def behavioral_sentence
        circadian = first_trait_for_obj_uris(
          Eol::Uris.nocturnal,
          Eol::Uris.diurnal,
          Eol::Uris.crepuscular
        )
        solitary = first_trait_for_obj_uris(Eol::Uris.solitary)
        begin_traits = [solitary, circadian].compact
        trophic = first_trait_for_pred_uri(Eol::Uris.trophic_level)
        trophic_part = trait_sentence_part("%s", trophic) if trophic
        sentence = nil

        add_sentence do |subj, is, _|
          if begin_traits.any?
            begin_parts = begin_traits.collect do |t|
              trait_sentence_part("%s", t)
            end

            if trophic_part
              sentence = "#{subj} #{is} #{a_or_an(begin_traits.first)} #{begin_parts.join(", ")} #{trophic_part}."
            else
              sentence = "#{subj} #{is} #{begin_parts.join(" and ")}."
            end
          elsif trophic_part
            sentence = "#{subj} #{is} #{a_or_an(trophic)} #{trophic_part}."
          end

          sentence
        end
      end

      def lifespan_size_sentence
        lifespan_part = nil
        size_part = nil

        lifespan_trait = first_trait_for_pred_uri(Eol::Uris.lifespan)
        if lifespan_trait
          value = lifespan_trait[:measurement]
          units_name = lifespan_trait.dig(:units, :name)

          if value && units_name
            lifespan_part = "are known to live for #{value} #{units_name}"
          end
        end

        size_traits = traits_for_pred_uris(Eol::Uris.body_mass)
        size_traits = traits_for_pred_uris(Eol::Uris.body_length) if size_traits.empty?

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
            size_part = "can grow to #{largest_value_trait[:measurement]} #{largest_value_trait[:units][:name]}"
          end
        end

        if lifespan_part || size_part
          add_sentence do |_, __, ___|
            "Individuals #{[lifespan_part, size_part].compact.to_sentence}."
          end
        end
      end

      def reproduction_sentences
        matches = reproduction_matches

        add_sentence do |subj, is, has|
          vpart = if matches.has_type?(:v)
                    v_vals = matches.by_type(:v).collect do |match|
                      trait_sentence_part("%s", match.trait)
                    end.to_sentence

                    "#{subj} #{has} #{v_vals}"
                  else
                    nil
                  end

          wpart = if matches.has_type?(:w)
                    w_vals = matches.by_type(:w).collect do |match|
                      trait_sentence_part(
                        "#{a_or_an(match.trait)} %s",
                        match.trait
                      )
                    end.to_sentence

                    "#{is} #{w_vals}"
                  else
                    nil
                  end

          if vpart && wpart
            wpart = "#{pronoun_for_rank} #{wpart}"
            "#{vpart}; #{wpart}."
          elsif vpart
            "#{vpart}."
          elsif wpart
            "#{subj} #{wpart}."
          end
        end

        if matches.has_type?(:y)
          add_sentence do |subj, is, has|
            y_parts = matches.by_type(:y).collect do |match|
              trait_sentence_part("%s #{match.trait[:predicate][:name]}", match.trait)
            end.to_sentence

            "#{subj} #{has} #{y_parts}."
          end
        end

        if matches.has_type?(:x)
          add_sentence do |_, __, ___|
            x_parts = matches.by_type(:x).collect do |match|
              trait_sentence_part("%s", match.trait)
            end.to_sentence

            "Reproduction is #{x_parts}."
          end
        end

        if matches.has_type?(:z)
          add_sentence do |subj, is, has|
            z_parts = matches.by_type(:z).collect do |match|
              trait_sentence_part("%s", match.trait)
            end.to_sentence

            "#{subj} #{has} parental care (#{z_parts})."
          end
        end
      end

      def motility_sentence
        matches = MotilityGroupMatcher.match_all(traits_for_pred_uris(
          Eol::Uris.motility,
          Eol::Uris.locomotion
        ))

        if matches.has_type?(:c)
          add_sentence do |subj, _, __|
            match = matches.first_of_type(:c)
            trait_sentence_part(
              "#{subj} relies on %s to move around.",
              match.trait
            )
          end
        elsif matches.has_type?(:a) && matches.has_type?(:b)
          add_sentence do |subj, is, _|
            a_match = matches.first_of_type(:a)
            b_match = matches.first_of_type(:b)

            a_part = trait_sentence_part(
              "#{subj} #{is} #{a_or_an(a_match.trait)} %s",
              a_match.trait
            )

            trait_sentence_part(
              "#{a_part} %s.",
              b_match.trait
            )
          end
        elsif matches.has_type?(:a)
          add_sentence do |subj, is, _|
            match = matches.first_of_type(:a)
            organism_animal = @page.animal? ? "animal" : "organism"
            trait_sentence_part(
              "#{subj} #{is} #{a_or_an(match.trait)} %s #{organism_animal}.",
              match.trait
            )
          end
        elsif matches.has_type?(:b)
          add_sentence do |subj, is, _|
            match = matches.first_of_type(:b)
            trait_sentence_part(
              "#{subj} #{is} #{a_or_an(match.trait)} %s.",
              match.trait
            )
          end
        end
      end

      def plant_description_sentence
        leaf_traits = Eol::Uris.flopos.collect { |uri| first_trait_for_pred_uri(uri) }.compact
        flower_trait = first_trait_for_pred_uri(Eol::Uris.flower_color)
        fruit_trait = first_trait_for_pred_uri(Eol::Uris.fruit_type)
        leaf_part = nil
        flower_part = nil
        fruit_part = nil

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
          add_sentence do |subj, is, has|
            "#{subj} #{has} #{parts.to_sentence}."
          end
        end
      end

      def flower_visitor_sentence
        traits = traits_for_pred_uris(Eol::Uris.flowers_visited_by).uniq do |t|
          t.dig(:object_term, :uri)
        end.slice(0, FLOWER_VISITOR_LIMIT)

        if traits && traits.any?
          parts = traits.collect { |trait| trait_sentence_part("%s", trait) }
          add_sentence do |_, __, ___|
            "Flowers are visited by #{parts.to_sentence}."
          end
        end
      end

      def fixes_nitrogen_sentence
        trait = first_trait_for_pred_and_obj(Eol::Uris.fixes, Eol::Uris.nitrogen)

        if trait
          fixes_label = is_species? ? "fixes" : "fix"
          fixes_part = term_sentence_part("%s", fixes_label, nil, trait[:predicate])

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
        forms_traits = @page.grouped_data[Eol::Uris.forms]

        if forms_traits.any?
          lifestage_trait = forms_traits.find do |t|
            t.[](:lifestage_term)&.[](:name)&.present?
          end

          if lifestage_trait
            trait = lifestage_trait
            lifestage = trait.dig(:lifestage_term, :name)&.capitalize
          else
            trait = forms_traits.first
            lifestage = nil
          end

          begin_part = [lifestage, name_clause].compact.join(" ")
          form_part = term_sentence_part("%s", "form", nil, trait[:predicate])

          if trait
            add_sentence do |_, __, ___|
              trait_sentence_part(
                "#{begin_part} #{form_part} %ss.", #extra s for plural, not a typo
                trait
              )
            end
            report_name_used
          end
        end
      end

      def ecosystem_engineering_sentence
        trait = first_trait_for_pred_uri(Eol::Uris.ecosystem_engineering)

        if trait
          add_sentence do |subj, is, _|
            trait_sentence_part("#{subj} #{is} #{a_or_an(trait)} %s.", trait)
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
        a2_name = a2_node.page&.vernacular&.string || a2_node.vernacular
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
        if !@full_name_used && @page.vernacular
          "#{@page.canonical} (#{@page.vernacular.string.titlecase})"
        else
          @name_clause ||= @page.vernacular_or_canonical
        end
      end

      # ...has a value with parent http://purl.obolibrary.org/obo/ENVO_00000447 for measurement type
      # http://eol.org/schema/terms/Habitat
      def is_it_marine?
        env_terms = gather_terms([Eol::Uris.habitat_includes])
        has_data_for_pred_terms(
          env_terms,
          values: [Eol::Uris.marine]
        ) &&
        !has_data_for_pred_terms(
          env_terms,
          values: [Eol::Uris.terrestrial]
        )
      end

      def freshwater_trait
        @freshwater_trait ||= first_trait_for_obj_uris(Eol::Uris.freshwater)
      end

      def native_range_traits
        @native_range_traits ||= traits_for_pred_uris(Eol::Uris.native_range)
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

      def first_trait_for_pred_uri(pred_uri)
        terms = gather_terms(pred_uri)

        terms.each do |term|
          recs = @page.grouped_data[term]

          if recs && recs.any?
            return recs.first
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
        terms = gather_terms(pred_uri)
        traits = []

        terms.each do |term|
          recs = @page.grouped_data[term]

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
        Array(uris).each { |uri| terms << uri ; terms += TraitBank.descendants_of_term(uri).map { |t| t['uri'] } }
        terms.compact
      end

      def add_extinction_sentence
        trait = first_trait_for_obj_uris(Eol::Uris.extinct)
        if trait
          add_sentence do |_, __, ___|
            term_sentence_part("This species is %s.", "extinct", Eol::Uris.extinction, trait[:object_term])
          end

          true
        else
          false
        end
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
        values.any? ? values.uniq.to_sentence : nil
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
        result << conservation_sentence_part("as %s by the US Fish and Wildlife Service", status_recs[:usfw]) if status_recs.include?(:usfw)
        result << conservation_sentence_part("in %s", status_recs[:cites]) if status_recs.include?(:cites)
        if result.any?
          add_sentence do |subj, _, __|
            "#{subj} is listed #{result.to_sentence(words_connector: ", ", last_word_connector: " and ")}."
          end
        end

      end

      def conservation_sentence_part(fstr, rec)
        term_sentence_part(
          fstr,
          rec[:name],
          Eol::Uris::Conservation.status,
          rec[:object_term],
          rec[:source]
        )
      end

      def term_toggle_id(term_name)
        "brief-summary-#{term_name.gsub(/\s/, "-")}"
      end

      def term_tag(label, pred_uri, term, trait_source = nil)
        toggle_id = term_toggle_id(label)

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

      def trait_sentence_part(format_str, trait)
        return '' if trait.nil?

        if trait[:object_page_id]
          association_sentence_part(format_str, trait[:object_page_id])
        else
          name = trait[:object_term].nil? ? '(no object term)' : trait[:object_term][:name]
          pred_uri = trait[:predicate].nil? ? '(no predicate uri)' : trait[:predicate][:uri]
          obj = trait[:object_term]
          term_sentence_part(
            format_str,
            name,
            pred_uri,
            obj
          )
        end
      end

      def association_sentence_part(format_str, object_page_id)
        target_page = @page.associated_page(object_page_id)
        target_page_part = if target_page.nil?
                             Rails.logger.warn("Missing associated page for auto-generated text: #{object_page_id}!")
                             "(page not found)"

                           else
                             view.link_to(target_page.name.html_safe, target_page)
                           end
        sprintf(format_str, target_page_part)
      end
    # end private
  end
end
