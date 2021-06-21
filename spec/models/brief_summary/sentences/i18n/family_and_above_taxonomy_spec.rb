require 'rails_helper'

RSpec.describe 'BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy' do
  describe '#to_s' do 
    def test_locale_and_rank(locale, treat_as)
      full_name = 'Pagename (pagename)'
      a1 = "<a>Ancestor</a>"

      rank = instance_double('Rank')
      allow(rank).to receive(:treat_as) { treat_as }

      page = instance_double('BriefSummary::PageDecorator')
      allow(page).to receive(:full_name_clause) { full_name }
      allow(page).to receive(:a1) { a1 }
      allow(page).to receive(:rank) { rank }
      allow(page).to receive(:family_or_above?) { true }

      sentence = BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy.new(page)
      expected = I18n.t(
        "brief_summary.taxonomy.family_above.#{treat_as}", 
        locale: locale,
        name1: full_name,
        name2: a1
      )

      expect(sentence.to_s).to eq(expected)
    end

    it "returns the appropriate string for each enabled locale/valid rank" do
      treat_as = Rank.treat_as
        .map { |v| v.first }
        .filter { |t| Rank.treat_as[t] <= Rank.treat_as[:r_family] }

      I18n.available_locales.each do |l|
        treat_as.each do |t|
          test_locale_and_rank(l, t)
        end
      end
    end

    it "raises an error when page is not family_or_above?" do
      page = instance_double('BriefSummary::PageDecorator')
      allow(page).to receive(:family_or_above?) { false }

      expect { BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy.new(page) }.to raise_error(TypeError)
    end
  end
end

