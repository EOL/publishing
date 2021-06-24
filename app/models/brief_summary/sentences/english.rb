# provides methods for building English-only brief summary sentences
class BriefSummary
  module Sentences
    class English
      def initialize(page, helper)
        @page = page
        @helper = helper
      end

      def below_family_taxonomy
        return BriefSummary::Sentences::Result.invalid unless @page.below_family?
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

        if match = @page.growth_habit_matches.first_of_type(:has_an_x_growth_form)
          BriefSummary::Sentences::Result.valid(@helper.add_trait_val_to_fmt(
            "They have #{a_or_an(match.trait)} %s growth form.",
            match.trait
          ))
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
    end
  end
end
