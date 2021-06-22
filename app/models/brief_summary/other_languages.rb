class BriefSummary
  class OtherLanguages
    include BriefSummary::Shared

    attr_reader :view, :sentences

    def initialize(page, view, locale)
      @page = page
      @view = view
      @locale = locale

      # TODO: extract/remove these!
      @sentences = []
      @terms = []
      @full_name_used = false
      build_sentences
    end

    def build_sentences
      if @page.family_or_above?
        @sentences << BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy.new(@page, @locale)
      elsif @page.below_family?
        @sentences << BriefSummary::Sentences::I18n::BelowFamilyTaxonomy.new(@page, @locale) 
      end

      #if genus_or_below?
      #  genus_and_below
      #end
    end

    def below_family_taxonomy_sentence
      add_sentence do
        if a2.present?
          I18n.t(
            "brief_summary.below_family_taxonomy.with_family.#{@page.rank.treat_as}", 
            name1: full_name_clause,
            name2: a1,
            name3: a2
          )
        else
          I18n.t(
            "brief_summary.below_family_taxonomy.no_family.#{@page.rank.treat_as}", 
            name1: full_name_clause,
            name2: a1
          )
        end
      end
    end

    def above_family
      add_above_family_group_sentence
    end

    def genus_and_below
      add_extinction_sentence
    end
  end
end

