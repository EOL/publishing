class BriefSummary
  module Sentences
    module I18n
      class FamilyAndAboveTaxonomy
        def initialize(page)
          raise TypeError, "page not family_or_above?" unless page.family_or_above?

          treat_as = page.rank.treat_as
          @string = ::I18n.t(
            "brief_summary.taxonomy.family_above.#{treat_as}", 
            name1: page.full_name_clause, 
            name2: page.a1
          )
        end

        def to_s
          @string
        end
      end
    end
  end
end

