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

      def extinction
        unless @page.genus_or_below? && @page.extinct?
          return BriefSummary::Sentences::Result.invalid
        end
        
        key = "extinction.#{@page.rank.treat_as}_html"
        val = i18n_w_term(
          key, 
          TermNode.safe_find_by_alias('extinction_status'), 
          @page.extinct_trait.object_term
        )
        BriefSummary::Sentences::Result.valid(val)
      end

      def below_family_taxonomy
        return BriefSummary::Sentences::Result.invalid unless @page.below_family? && @page.a1.present?

        value = @page.a2.present? ?
          I18n.t(
            "brief_summary.taxonomy.below_family.with_family.#{@page.rank.treat_as}",
            name1: @page.full_name,
            name2: @page.a1,
            name3: @page.a2,
            locale: @locale
          ) :
          I18n.t(
            "brief_summary.taxonomy.below_family.without_family.#{@page.rank.treat_as}",
            name1: @page.full_name,
            name2: @page.a1,
            locale: @locale
          )

        BriefSummary::Sentences::Result.valid(value)
      end

      def marine
        if @page.genus_or_below? && @page.marine?
          BriefSummary::Sentences::Result.valid(I18n.t(
            'brief_summary.marine_html',
            class_str: BriefSummary::TermTagger.tag_class_str,
            id: @helper.toggle_id(
              TermNode.safe_find_by_alias('habitat'),
              TermNode.safe_find_by_alias('marine'),
              nil
            ),
            locale: @locale
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def freshwater
        if @page.genus_or_below? && @page.freshwater?
          BriefSummary::Sentences::Result.valid(I18n.t(
            'brief_summary.freshwater_html',
            class_str: BriefSummary::TermTagger.tag_class_str,
            id: @helper.toggle_id(
              @page.freshwater_trait.predicate,
              @page.freshwater_trait.object_term,
              nil
            ),
            locale: @locale
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end

      def fix_nitrogen
        predicate = TermNode.safe_find_by_alias('fixes')
        object = TermNode.safe_find_by_alias('nitrogen')

        trait = @page.first_trait_for_predicate(predicate, for_object_term: object)

        if trait
          BriefSummary::Sentences::Result.valid(I18n.t(
            'brief_summary.fix_nitrogen_html',
            predicate_id: @helper.toggle_id(nil, predicate, nil),
            object_id: @helper.toggle_id(predicate, object, nil),
            class_str: BriefSummary::TermTagger.tag_class_str,
            locale: @locale
          ))
        else
          BriefSummary::Sentences::Result.invalid
        end
      end
      private
      def i18n_w_term(key, predicate, term)
        toggle_id = @helper.toggle_id(predicate, term, nil)
        full_key = "brief_summary.#{key}"

        I18n.t(
          full_key,
          class_str: BriefSummary::TermTagger.tag_class_str,
          id: toggle_id,
          locale: @locale
        )
      end
    end
  end
end

