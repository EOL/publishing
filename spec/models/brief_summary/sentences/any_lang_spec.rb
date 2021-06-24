require 'rails_helper'

RSpec.describe('BriefSummary::Sentences::AnyLang') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:helper) { instance_double('BriefSummary::Sentences::Helper') }

  describe '#family_and_above_taxonomy' do
    def test_locale_and_rank(locale, treat_as)
      full_name = 'Pagename (pagename)'
      a1 = "<a>Ancestor</a>"

      rank = instance_double('Rank')
      allow(rank).to receive(:treat_as) { treat_as }

      allow(page).to receive(:full_name) { full_name }
      allow(page).to receive(:a1) { a1 }
      allow(page).to receive(:rank) { rank }
      allow(page).to receive(:family_or_above?) { true }

      sentences = BriefSummary::Sentences::AnyLang.new(page, helper, locale)

      expected = I18n.t(
        "brief_summary.taxonomy.family_above.#{treat_as}", 
        locale: locale,
        name1: full_name,
        name2: a1
      )

      expect(sentences.family_and_above_taxonomy.value).to eq(expected)
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

    context 'when page is not family_or_above?' do
      before { allow(page).to receive(:family_or_above?) { false } }

      it do
        sentences = BriefSummary::Sentences::AnyLang.new(page, helper, :en)
        expect(sentences.family_and_above_taxonomy).to_not be_valid
      end
    end
  end
end
