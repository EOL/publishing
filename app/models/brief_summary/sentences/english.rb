# provides methods for building English-only brief summary sentences
class BriefSummary
  module Sentences
    class English
      FLOWER_VISITOR_LIMIT = 4

      def initialize(page, helper)
        @page = page
        @helper = helper
      end

      def below_family_taxonomy
        return BriefSummary::Sentences::Result.invalid unless @page.below_family?
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        val = ''
        matches = @page.growth_habit_matches

        if match = matches.first_of_type(:species_of_x)
          val = species_of_x_part(match)
        elsif match = matches.first_of_type(:species_of_lifecycle_x)
          lifecycle_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('lifecycle_habit'))

          if lifecycle_trait
            lifecycle_part = @helper.add_trait_val_to_fmt('%s', lifecycle_trait)
            val = @helper.add_trait_val_to_fmt(
              "#{@page.full_name} is a #{@page.rank_name} of #{lifecycle_part} %s",
              match.trait
            )
          else
            val = species_of_x_part(match)
          end
        elsif match = matches.first_of_type(:species_of_x_a1)
          val = @helper.add_trait_val_to_fmt(
            "#{@page.full_name} is a #{@page.rank_name} of %s #{@page.a1}",
            match.trait
          )
        else
          val = "#{@page.full_name} is a #{@page.rank_name} of #{@page.a1}"
        end

        val = "#{val} in the family #{@page.a2}" if @page.a2.present?

        BriefSummary::Sentences::Result.valid(val + '.')
      end

      def descendants
        return BriefSummary::Sentences::Result.invalid unless @page.above_family?

        desc_info = @page.desc_info
        return BriefSummary::Sentences::Result.invalid if desc_info.nil?

        value = "There #{is_or_are(desc_info.species_count)} #{desc_info.species_count} species of #{@page.name}, in #{@helper.pluralize(desc_info.genus_count, 'genus', 'genera')} and #{@helper.pluralize(desc_info.family_count, 'family', 'families')}."

        BriefSummary::Sentences::Result.valid(value)
      end

      def first_appearance
        return BriefSummary::Sentences::Result.invalid unless @page.above_family?
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        first_appearance_trait = @page.first_trait_for_predicate(
          TermNode.find_by_alias('fossil_first'),
          with_object_term: true
        )

        return BriefSummary::Sentences::Result.invalid if first_appearance_trait.nil?

        BriefSummary::Sentences::Result.valid(@helper.add_trait_val_to_fmt(
          "This #{@page.rank_name} has been around since the %s.",
          first_appearance_trait
        ))
      end

      def is_an_x_growth_form
        return BriefSummary::Sentences::Result.invalid unless @page.genus_or_below?
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        if match = @page.growth_habit_matches.first_of_type(:is_an_x)
          BriefSummary::Sentences::Result.valid(@helper.add_trait_val_to_fmt(
            "They are %ss.",
            match.trait
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def has_an_x_growth_form
        return BriefSummary::Sentences::Result.invalid unless @page.genus_or_below?
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        if match = @page.growth_habit_matches.first_of_type(:has_an_x_growth_form)
          BriefSummary::Sentences::Result.valid(@helper.add_trait_val_to_fmt(
            "They have #{a_or_an(match.trait)} %s growth form.",
            match.trait
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def conservation
        return BriefSummary::Sentences::Result.invalid unless @page.genus_or_below?
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        status_recs = ConservationStatus.new(@page).by_provider
        result = []

        result << conservation_part("as %s by IUCN", status_recs[:iucn]) if status_recs.include?(:iucn)
        result << conservation_part("as %s by COSEWIC", status_recs[:cosewic]) if status_recs.include?(:cosewic)
        result << conservation_part("as %s by the US Fish and Wildlife Service", status_recs[:usfw]) if status_recs.include?(:usfw)
        result << conservation_part("in %s", status_recs[:cites]) if status_recs.include?(:cites)

        if result.any?
          BriefSummary::Sentences::Result.valid("They are listed #{result.to_sentence}.")
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def native_range
        return BriefSummary::Sentences::Result.invalid unless @page.genus_or_below? && @page.has_native_range?
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        predicate = TermNode.find_by_alias('native_range')
        traits = @page.native_range_traits

        BriefSummary::Sentences::Result.valid("They are native to #{@helper.trait_vals_to_sentence(traits, predicate)}.")
      end

      def found_in
        predicate = TermNode.find_by_alias('biogeographic_realm')
        traits = @page.traits_for_predicate(predicate)

        if (
          !@page.genus_or_below? ||
          @page.has_native_range? ||
          traits.empty?
        )
          return BriefSummary::Sentences::Result.invalid
        end

        BriefSummary::Sentences::Result.valid("They are found in #{@helper.trait_vals_to_sentence(traits, predicate)}.")
      end

      def landmark_children
        if @page.landmark_children.any?
          links = @page.landmark_children.map { |c| @helper.page_link(c) }
          BriefSummary::Sentences::Result.valid("It includes groups like #{links.to_sentence}.")
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def behavior
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        circadian = @page.first_trait_for_object_terms([
          TermNode.find_by_alias('nocturnal'),
          TermNode.find_by_alias('diurnal'),
          TermNode.find_by_alias('crepuscular')
        ])
        solitary = @page.first_trait_for_object_term(TermNode.find_by_alias('solitary'))
        begin_traits = [solitary, circadian].compact
        trophic = @page.first_trait_for_predicate(
          TermNode.find_by_alias('trophic_level'),
          exclude_values: [TermNode.find_by_alias('variable')]
        )
        sentence = nil
        trophic_part = @helper.add_trait_val_to_fmt("%s", trophic, pluralize: true) if trophic

        if begin_traits.any?
          begin_parts = begin_traits.collect do |t|
            @helper.add_trait_val_to_fmt("%s", t)
          end

          if trophic_part
            sentence = "They are #{begin_parts.join(", ")} #{trophic_part}."
          else
            sentence = "They are #{begin_parts.join(" and ")}."
          end
        elsif trophic_part
          sentence = "They are #{trophic_part}."
        end

        if sentence
          BriefSummary::Sentences::Result.valid(sentence)
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def lifespan_size
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        lifespan_part = nil
        size_part = nil

        lifespan_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('lifespan'), includes: [:units_term])

        if lifespan_trait
          value = lifespan_trait.measurement
          units_name = lifespan_trait.units_term&.name

          if value && units_name
            are = @page.extinct? ? 'were' : 'are'
            lifespan_part = "#{are} known to live for #{value} #{units_name}"
          end
        end

        if (size_trait = @page.greatest_value_size_trait).present?
          can = @page.extinct? ? 'could' : 'can'
          size_part = "#{can} grow to #{size_trait.measurement} #{size_trait.units_term.name}"
        end

        if lifespan_part || size_part
          BriefSummary::Sentences::Result.valid("Individuals #{[lifespan_part, size_part].compact.to_sentence}.")
        else
          BriefSummary::Sentences::Result.invalid

        end
      end

      def plant_description
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        leaf_traits = @page.leaf_traits
        flower_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('flower_color'))
        fruit_trait = @page.first_trait_for_predicate(TermNode.find_by_alias('fruit_type'))
        leaf_part = nil
        flower_part = nil
        fruit_part = nil

        if leaf_traits.any?
          leaf_parts = leaf_traits.collect { |trait| @helper.add_trait_val_to_fmt("%s", trait) }
          leaf_part = "#{leaf_parts.join(", ")} leaves"
        end

        if flower_trait
          flower_part = @helper.add_trait_val_to_fmt("%s flowers", flower_trait)
        end

        if fruit_trait
          fruit_part = @helper.add_trait_val_to_fmt("%s", fruit_trait)
        end

        parts = [leaf_part, flower_part, fruit_part].compact

        if parts.any?
          BriefSummary::Sentences::Result.valid("They have #{parts.to_sentence}.")
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def visits_flowers
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        flower_visitor_sentence_helper(:traits_for_predicate, :object_page) do |page_part|
          "They visit flowers of #{page_part}."
        end
      end

      def flowers_visited_by
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        flower_visitor_sentence_helper(:object_traits_for_predicate, :page) do |page_part|
          "Flowers are visited by #{page_part}."
        end
      end

      def form1
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        form_sentence_helper(@page.form_trait1)
      end

      def form2
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        form_sentence_helper(@page.form_trait2)
      end

      def ecosystem_engineering
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        trait = @page.first_trait_for_predicate(TermNode.find_by_alias('ecosystem_engineering'))
        obj_name = trait&.object_term&.name

        if obj_name
          BriefSummary::Sentences::Result.valid(@helper.add_term_to_fmt(
            "They are %s.",
            obj_name.pluralize,
            trait.predicate,
            trait.object_term
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def reproduction_vw
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        matches = @page.reproduction_matches

        vpart = if matches.has_type?(:v)
                  v_vals = matches.by_type(:v).collect do |match|
                    @helper.add_trait_val_to_fmt("%s", match.trait)
                  end.to_sentence

                  "they have #{v_vals}"
                else
                  nil
                end

        wpart = if matches.has_type?(:w)
                  w_vals = matches.by_type(:w).collect do |match|
                    @helper.add_trait_val_to_fmt(
                      "%s",
                      match.trait,
                      pluralize: true
                    )
                  end.to_sentence

                  "they are #{w_vals}"
                else
                  nil
                end

        sentence = (vpart || wpart) ?
          [vpart, wpart].compact.join('; ') :
          nil

        if sentence
          BriefSummary::Sentences::Result.valid(sentence.upcase_first + '.')
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def reproduction_y
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        matches = @page.reproduction_matches

        if matches.has_type?(:y)
          parts = matches.by_type(:y).collect do |match|
            @helper.add_trait_val_to_fmt("%s #{match.trait.predicate.name}", match.trait)
          end

          BriefSummary::Sentences::Result.valid("They have #{parts.to_sentence}.")
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def reproduction_x
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        matches = @page.reproduction_matches

        if matches.has_type?(:x)
          parts = matches.by_type(:x).collect do |match|
            @helper.add_trait_val_to_fmt('%s', match.trait)
          end

          is = @page.extinct? ? 'was' : 'is'

          BriefSummary::Sentences::Result.valid("Reproduction #{is} #{parts.to_sentence}.")
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def reproduction_z
        return BriefSummary::Sentences::Result.invalid unless @page.page_node

        matches = @page.reproduction_matches

        if matches.has_type?(:z)
          parts = matches.by_type(:z).collect do |match|
            @helper.add_trait_val_to_fmt('%s', match.trait)
          end

          BriefSummary::Sentences::Result.valid("They have parental care (#{parts.to_sentence}).")
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def motility
        return BriefSummary::Sentences::Result.invalid unless @page.page_node
        
        matches = @page.motility_matches
        sentence = nil

        if matches.has_type?(:c)
          match = matches.first_of_type(:c)
          sentence = @helper.add_trait_val_to_fmt('They rely on %s to move around.', match.trait)
        elsif matches.has_type?(:a) && matches.has_type?(:b)
          a_match = matches.first_of_type(:a)
          b_match = matches.first_of_type(:b)
          a_part = @helper.add_trait_val_to_fmt('They are %s', a_match.trait)
          sentence = @helper.add_trait_val_to_fmt("#{a_part} %s.", b_match.trait, pluralize: true)
        elsif matches.has_type?(:a)
          match = matches.first_of_type(:a)
          animals = @page.animal? ? 'animals' : 'organisms'
          sentence = @helper.add_trait_val_to_fmt("They are %s #{animals}.", match.trait)
        elsif matches.has_type?(:b)
          match = matches.first_of_type(:b)
          sentence = @helper.add_trait_val_to_fmt(
            "They are %s.",
            match.trait,
            pluralize: true
          )
        end

        if sentence
          BriefSummary::Sentences::Result.valid(sentence)
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      private
      def a_or_an(trait)
        return '' unless trait.object_term&.name.present?

        word = trait.object_term.name
        %w(a e i o u).include?(word[0].downcase) ? "an" : "a"
      end

      def is_or_are(count)
        count == 0 || count > 1 ?
          'are' :
          'is'
      end

      def species_of_x_part(match)
        @helper.add_trait_val_to_fmt(
          "#{@page.full_name} is a #{@page.rank_name} of %s",
          match.trait
        )
      end

      def conservation_part(fstr, trait)
        @helper.add_term_to_fmt(
          fstr,
          trait.object_term.name,
          TermNode.find_by_alias('conservation_status'),
          trait.object_term,
          trait.source
        )
      end

      def flower_visitor_sentence_helper(trait_fn, page_fn)
        pages = @page.send(trait_fn, TermNode.find_by_alias('visits_flowers_of')).map do |t|
          t.send(page_fn)
        end.uniq.slice(0, FLOWER_VISITOR_LIMIT)

        if pages.any?
          parts = pages.collect { |page| @helper.add_obj_page_to_fmt("%s", page) }
          BriefSummary::Sentences::Result.valid(yield parts.to_sentence)
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def form_sentence_helper(trait)
        if trait
          lifestage = trait.lifestage_term&.name&.capitalize
          begin_part = [lifestage, @page.name].compact.join(" ")
          form_part = @helper.add_term_to_fmt("%s", "form", nil, trait.predicate)

          BriefSummary::Sentences::Result.valid(@helper.add_trait_val_to_fmt(
            "#{begin_part} #{form_part} %ss.", #extra s for plural, not a typo
            trait
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end
    end
  end
end
