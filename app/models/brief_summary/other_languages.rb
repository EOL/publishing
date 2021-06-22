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
      taxonomy
    end

    def taxonomy
      if @page.family_or_above?
        @sentences << BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy.new(@page, @locale)
      elsif @page.below_family?
        @sentences << BriefSummary::Sentences::I18n::BelowFamilyTaxonomy.new(@page, @locale) 
      end
    end
  end
end

