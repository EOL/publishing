class BriefSummary
  class English
    include BriefSummary::Shared

    attr_accessor :view

    FLOWER_VISITOR_LIMIT = 4
    SUBJ_RESET = 3
    LEAF_PREDICATES = [
      TermNode.find_by_alias('leaf_complexity'),
      TermNode.find_by_alias('leaf_morphology')
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
    def add_sentences
      if is_above_family?
        above_family
      elsif a1.present?
        if is_family?
          family
        elsif below_family?
          below_family_taxonomy_sentence

          if genus_or_below?
            genus_and_below
          end
        end
      end

      landmark_children
      plant_description_sentence
      flower_visitor_sentences
      fixes_nitrogen_sentence
      forms_sentence
      ecosystem_engineering_sentence
      behavioral_sentence

      if is_species?
        lifespan_size_sentence
      end

      reproduction_sentences
      motility_sentence
    end

    private
    LandmarkChildLimit = 3

    IUCN_URIS = Set[
      TermNode.find_by_alias('iucn_en'),
      TermNode.find_by_alias('iucn_cr'),
      TermNode.find_by_alias('iucn_ew'),
      TermNode.find_by_alias('iucn_nt'),
      TermNode.find_by_alias('iucn_vu')
    ]

    def pronoun_for_rank
      "they"
    end

    def above_family
      add_above_family_group_sentence

      rank_name = @page.rank&.treat_as.present? ?
        @page.rank.i18n_name : 
        'group'

      desc_info = @page.desc_info
      if desc_info.present?
        add_sentence_helper do |_, __, ___|
          "There #{is_or_are(desc_info.species_count)} #{desc_info.species_count} species of #{@page.name}, in #{view.pluralize(desc_info.genus_count, "genus", "genera")} and #{view.pluralize(desc_info.family_count, "family")}."
        end
      end

      first_appearance_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('fossil_first'), with_object_term: true)

      if first_appearance_trait
        add_sentence_helper do |_, __, ___|
          trait_sentence_part("This #{rank_name} has been around since the %s.", first_appearance_trait)
        end
      end
    end

    def below_family_taxonomy_sentence
      # taxonomy sentence:
      rank = @page.rank.human_treat_as
      what = a1
      parts = []

      add_sentence do
        if match = growth_habit_matches.first_of_type(:species_of_x)
          parts << trait_sentence_part(
            "#{full_name_clause} is a #{rank} of %s",
            match.trait
          )
        elsif match = growth_habit_matches.first_of_type(:species_of_lifecycle_x)
          lifecycle_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('lifecycle_habit'))
          if lifecycle_trait
            lifecycle_part = trait_sentence_part("%s", lifecycle_trait)
            parts << trait_sentence_part(
              "#{full_name_clause} is a #{rank} of #{lifecycle_part} %s",
              match.trait
            )
          else # TODO: DRY
            parts << trait_sentence_part(
              "#{full_name_clause} is a #{rank} of %s",
              match.trait
            )
          end
        elsif match = growth_habit_matches.first_of_type(:species_of_x_a1)
          parts << trait_sentence_part(
            "#{full_name_clause} is a #{rank} of %s #{what}",
            match.trait
          )
        else
          parts << "#{full_name_clause} is a #{rank} of #{what}"
        end

        parts << " in the family #{a2}" if a2
        parts << "."
        parts.join("")
      end
    end

    # [name clause] is a[n] [A1] in the family [A2].
    def genus_and_below
      if match = growth_habit_matches.first_of_type(:is_an_x)
        add_sentence_helper do |subj, are, __|
          trait_sentence_part(
            "#{subj} #{are} %ss.",
            match.trait
          )
        end
      end

      if match = growth_habit_matches.first_of_type(:has_an_x_growth_form)
        add_sentence_helper do |subj, are, have|
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
        add_sentence_helper do |subj, are, _|
          term_sentence_part(
            "#{subj} #{are} found in %s.", "marine habitat", 
            TermNode.find_by_alias('habitat'), 
            TermNode.find_by_alias('marine')
          )
        end
      elsif freshwater_trait.present?
        add_sentence_helper do |subj, are, _|
          term_sentence_part("#{subj} #{are} associated with %s.", "freshwater habitat", freshwater_trait.predicate, freshwater_trait.object_term)
        end
      end


      native_range_part = values_to_sentence([TermNode.find_by_alias('native_range')])
      if native_range_part.present?
        add_sentence_helper do |subj, are, _|
          "#{subj} #{are} native to #{native_range_part}."
        end
      elsif g1
        add_sentence_helper do |subj, are, _|
          "#{subj} #{are} found in #{g1}."
        end
      end
    end

    # [name clause] is a genus in the [A1] family [A2].
    #
    def genus
      family = a2
      if family
        add_sentence do
          "#{full_name_clause} is a genus of #{a1} in the family #{family}."
        end
      else
        # We may have a few genera that don't have a family in their ancestry. In those cases, shorten the taxonomy sentence:
        # [name clause] is a genus in the [A1]
        add_sentence do
          "#{full_name_clause} is a genus of #{a1}."
        end
      end
    end

    # [name clause] is a family of [A1].
    #
    # This will look a little funny for those families with "family" vernaculars, but I think it's still acceptable, e.g.,
    # Rosaceae (rose family) is a family of plants.
    def family
      add_family_sentence
    end

    def landmark_children
      children = @page.native_node&.landmark_children(LandmarkChildLimit) || []

      if children.any?
        taxa_links = children.map { |c| view.link_to(c.page.vernacular_or_canonical(Locale.english), c.page) }
        add_sentence_helper do |subj, _, __|
          "#{subj} includes groups like #{to_sentence(taxa_links)}."
        end
      end
    end

    def behavioral_sentence
      circadian = @page.first_trait_for_object_terms([
        TermNode.find_by_alias('nocturnal'),
        TermNode.find_by_alias('diurnal'),
        TermNode.find_by_alias('crepuscular')
      ])
      solitary = @page.first_trait_for_object_terms([TermNode.find_by_alias('solitary')])
      begin_traits = [solitary, circadian].compact
      trophic = @page.first_trait_for_predicate(
        TermNode.find_by_alias('trophic_level'), 
        exclude_values: [TermNode.find_by_alias('variable')]
      )

      add_sentence_helper do |subj, are, _|
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

    def lifespan_size_sentence
      lifespan_part = nil
      size_part = nil

      add_sentence_helper do |subj, are, _|
        lifespan_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('lifespan'), includes: [:units_term])
        if lifespan_trait
          value = lifespan_trait.measurement
          units_name = lifespan_trait.units_term&.name

          if value && units_name
            lifespan_part = "#{are} known to live for #{value} #{units_name}"
          end
        end

        size_traits = @page.traits_for_predicate(TermNode.find_by_alias('body_mass'), includes: [:units_term])
        size_traits = @page.traits_for_predicate(TermNode.find_by_alias('body_length'), includes: [:units_term]) if size_traits.empty?

        if size_traits.any?
          largest_value_trait = nil

          size_traits.each do |trait|
            if trait.normal_measurement &&
               trait.measurement &&
               trait.units_term && (
               !largest_value_trait ||
               largest_value_trait.normal_measurement.to_f < trait.normal_measurement.to_f
            )
              largest_value_trait = trait
            end
          end

          if largest_value_trait
            can = extinct? ? 'could' : 'can' 
            size_part = "#{can} grow to #{largest_value_trait.measurement} #{largest_value_trait.units_term.name}"
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

      add_sentence_helper do |subj, are, have|
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
        add_sentence_helper do |subj, are, have|
          y_parts = to_sentence(matches.by_type(:y).collect do |match|
            trait_sentence_part("%s #{match.trait[:predicate][:name]}", match.trait)
          end)

          "#{subj} #{have} #{y_parts}."
        end
      end

      if matches.has_type?(:x)
        add_sentence_helper do |_, __, ___|
          x_parts = to_sentence(matches.by_type(:x).collect do |match|
            trait_sentence_part("%s", match.trait)
          end)

          is = extinct? ? 'was' : 'is'

          "Reproduction #{is} #{x_parts}."
        end
      end

      if matches.has_type?(:z)
        add_sentence_helper do |subj, are, have|
          z_parts = to_sentence(matches.by_type(:z).collect do |match|
            trait_sentence_part("%s", match.trait)
          end)

          "#{subj} #{have} parental care (#{z_parts})."
        end
      end
    end

    def motility_sentence
      matches = MotilityGroupMatcher.match_all(@page.traits_for_predicates([
        TermNode.find_by_alias('motility'),
        TermNode.find_by_alias('locomotion')
      ]))

      if matches.has_type?(:c)
        add_sentence_helper do |subj, _, __|
          match = matches.first_of_type(:c)
          trait_sentence_part(
            "#{subj} rely on %s to move around.",
            match.trait
          )
        end
      elsif matches.has_type?(:a) && matches.has_type?(:b)
        add_sentence_helper do |subj, are, _|
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
        add_sentence_helper do |subj, are, _|
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
        add_sentence_helper do |subj, are, _|
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
      leaf_traits = LEAF_PREDICATES.collect { |term| @page.first_trait_for_predicate(term) }.compact
      flower_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('flower_color'))
      fruit_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('fruit_type'))
      leaf_part = nil
      flower_part = nil
      fruit_part = nil

      add_sentence_helper do |subj, are, have|
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

    def flower_visitor_sentences
      visits_flowers_sentence
      flowers_visited_by_sentence
    end

    def visits_flowers_sentence
      flower_visitor_sentence_helper(:traits_for_predicate, :object_page) do |page_part|
        add_sentence_helper do |subj, __, ___|
          "#{subj} visit flowers of #{page_part}."
        end
      end
    end

    def flowers_visited_by_sentence
      flower_visitor_sentence_helper(:object_traits_for_predicate, :page) do |page_part|
        add_sentence_helper do |_, __, ___|
          "Flowers are visited by #{page_part}."
        end
      end
    end

    def flower_visitor_sentence_helper(trait_fn, page_fn)
      pages = @page.send(trait_fn, TermNode.find_by_alias('visits_flowers_of')).map do |t|
        t.send(page_fn)
      end.uniq.slice(0, FLOWER_VISITOR_LIMIT)

      if pages.any?
        parts = pages.collect { |page| association_sentence_part("%s", page) }
        yield to_sentence(parts)
      end
    end

    def fixes_nitrogen_sentence
      trait = @page.first_trait_for_predicate(TermNode.find_by_alias('fixes'), for_object_term: TermNode.find_by_alias('nitrogen'))

      if trait
        fixes_part = term_sentence_part("%s", 'fix', nil, trait.predicate)

        add_sentence_helper do |subj, _, __|
          term_sentence_part(
            "#{subj} #{fixes_part} %s.",
            "nitrogen",
            trait.predicate,
            trait.object_term
          )
        end
      end
    end

    def forms_sentence 
      # intentionally skip descendants of this term
      forms_traits = @page.traits_for_predicate(
        TermNode.find_by_alias('forms'), 
        exact_predicate: true, 
        includes: [:predicate, :object_term, :lifestage_term]
      ).uniq { |t| t.object_term&.uri }

      if forms_traits.any?
        lifestage_traits = forms_traits.find_all do |t|
          t.lifestage_term&.name.present?
        end

        other_traits = forms_traits.reject do |t|
          t.lifestage_term&.name.present?
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
      lifestage = trait.lifestage_term&.name&.capitalize
      begin_part = [lifestage, name_clause].compact.join(" ")
      form_part = term_sentence_part("%s", "form", nil, trait.predicate)

      add_sentence_helper do |_, __, ___|
        trait_sentence_part(
          "#{begin_part} #{form_part} %ss.", #extra s for plural, not a typo
          trait
        )
      end
    end

    def ecosystem_engineering_sentence
      trait = @page.first_trait_for_predicate(TermNode.find_by_alias('ecosystem_engineering'))

      if trait
        add_sentence_helper do |subj, are, _|
          obj_name = trait.object_term&.name

          if obj_name
            term_sentence_part("#{subj} #{are} %s.", obj_name.pluralize, trait.predicate, trait.object_term)
          else
            nil
          end
        end
      end
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

    # Print all values, separated by commas, with “and” instead of comma before the last item in the list.
    def values_to_sentence(predicates)
      values = @page.traits_for_predicates(predicates, return_predicate: true).map do |row|
        trait = row[:trait]

        if trait.object_term
          term_tag(trait.object_term.name, row[:predicate], trait.object_term)
        else
          trait.literal
        end
      end
      
      values.any? ? to_sentence(values.uniq) : nil
    end


    def rank_or_clade(node)
      node.rank.try(:name) || "clade"
    end

    # XXX: this does not always work (e.g.: "an unicorn")
    def a_or_an(trait)
      return unless trait[:object_term] && trait[:object_term][:name]
      word = trait[:object_term][:name]
      a_or_an_helper(word)
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
        add_sentence_helper do |subj, are, _|
          "#{subj} #{are} listed #{to_sentence(result)}."
        end
      end
    end

    def conservation_sentence_part(fstr, trait)
      term_sentence_part(
        fstr,
        trait.object_term.name,
        TermNode.find_by_alias('conservation_status'),
        trait.object_term,
        trait.source
      )
    end

    def term_toggle_id
      @term_toggle_count ||= -1
      @term_toggle_count += 1
      "brief-summary-toggle-#{@term_toggle_count}"
    end


    # use instead of Array#to_sentence to use correct locale for text, rather than global I18n.locale
    def to_sentence(a)
      a.to_sentence(locale: :en)
    end
    
    def a_or_an_helper(word)
      %w(a e i o u).include?(word[0].downcase) ? "an" : "a"
    end

    def add_sentence_helper
      are = extinct? ? 'were' : 'are' 
      have = extinct? ? 'had' : 'have'

      add_sentence do 
        yield('They', are, have)
      end
    end
  end
end

