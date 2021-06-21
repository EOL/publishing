class BriefSummary
  module Sentences
    module I18n
      class BelowFamilyTaxonomy
        def initialize(page)
          raise TypeError, 'page is not below_family?' unless page.below_family?

          @sentence = if page.a2.present?
            ::I18n.t(
              "brief_summary.taxonomy.below_family.with_family.#{page.rank.treat_as}",
              name1: page.full_name_clause,
              name2: page.a1,
              name3: page.a2
            )
          else
            ::I18n.t(
              "brief_summary.taxonomy.below_family.without_family.#{page.rank.treat_as}",
              name1: page.full_name_clause,
              name2: page.a1
            )
          end
        end

        def to_s
          @sentence
        end
      end
    end
  end
end

