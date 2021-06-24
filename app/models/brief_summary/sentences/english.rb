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

      private
      def species_of_x_part(match)
        @helper.add_trait_val_to_fmt(
          "#{@page.full_name} is a #{@page.rank_name} of %s",
          match.trait
        )
      end
    end
  end
end
