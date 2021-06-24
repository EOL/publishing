# Collection of translated sentences that can be used with any valid locale/language
class BriefSummary
  module Sentences
    class AnyLang
      def initialize(page, helper, locale)
        @page = page
        @helper = helper
        @locale = locale
      end

      def family_and_above_taxonomy
        return BriefSummary::Sentences::Result.invalid unless @page.family_or_above?

        value = I18n.t(
          "brief_summary.taxonomy.family_above.#{@page.rank.treat_as}",
          locale: @locale,
          name1: @page.full_name,
          name2: @page.a1
        )

        BriefSummary::Sentences::Result.valid(value)
      end
    end
  end
end

