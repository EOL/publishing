require 'rails_helper'

RSpec.describe 'BriefSummary::Sentences::I18n::BelowFamilyTaxonomy' do
  describe '#to_s' do
    context 'when page is below_family?' do
      let(:full_name) { "full_page_name" }
      let(:a1) { "a1_name" }
      let(:ranks) do 
        Rank.treat_as
          .map { |v| v.first }
          .filter { |t| Rank.treat_as[t] > Rank.treat_as[:r_family] }
      end

      def build_page(treat_as, a2)
        rank = instance_double('Rank')
        allow(rank).to receive(:treat_as) { treat_as }

        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:rank) { rank }
        allow(page).to receive(:below_family?) { true }
        allow(page).to receive(:a1) { a1 }
        allow(page).to receive(:a2) { a2 }
        allow(page).to receive(:full_name_clause) { full_name }

        page
      end

      def test_all_locales_and_ranks
        I18n.available_locales.each do |l|
          ranks.each { |treat_as| yield(l, treat_as) }
        end
      end

      context 'when a2 (family) is present' do
        it 'returns the correct string for each enabled locale/valid rank' do 
          test_all_locales_and_ranks do |locale, treat_as|
            a2 = "a2_name"

            page = build_page(treat_as, a2)

            sentence = BriefSummary::Sentences::I18n::BelowFamilyTaxonomy.new(page)
            expected = I18n.t(
              "brief_summary.taxonomy.below_family.with_family.#{treat_as}",
              name1: full_name,
              name2: a1,
              name3: a2
            )

            expect(sentence.to_s).to eq(expected)
          end
        end
      end

      context 'when a2 (family) is not present' do
        it 'returns the correct string for each enabled locale/valid rank' do
          test_all_locales_and_ranks do |locale, treat_as|
            page = build_page(treat_as, nil)

            sentence = BriefSummary::Sentences::I18n::BelowFamilyTaxonomy.new(page)
            expected = I18n.t(
              "brief_summary.taxonomy.below_family.without_family.#{treat_as}",
              name1: full_name,
              name2: a1
            )

            expect(sentence.to_s).to eq(expected)
          end
        end
      end
    end

    context 'when page is not below_family?' do
      it 'raises an error' do
        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:below_family?) { false }

        expect { BriefSummary::Sentences::I18n::BelowFamilyTaxonomy.new(page) }.to raise_error(TypeError)
      end
    end
  end
end
  
