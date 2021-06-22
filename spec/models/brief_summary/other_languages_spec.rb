require 'rails_helper'

RSpec.describe 'BriefSummary::OtherLanguages' do
  describe '#sentences' do
    context 'when page is family_or_above?' do
      it 'includes a FamilyAndAboveTaxonomy sentence' do
        taxonomy_sentence = instance_double('BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy')
        allow(BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy).to receive(:new) { taxonomy_sentence }

        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:family_or_above?) { true }

        summary = BriefSummary::OtherLanguages.new(page, nil, :en)

        expect(summary.sentences).to include(taxonomy_sentence)
      end

      # It's not worth testing for the absence of, say, BelowFamilyTaxonomy here. 
      # The unit tests for the sentences ensure that they raise errors on 
      # invalid input, so it would take a very convoluted implementation to include
      # invalid sentences.
    end

    context 'when page is below_family?' do
      it 'includes a BelowFamilyTaxonomy sentence' do
        taxonomy_sentence = instance_double('BriefSummary::Sentences::I18n::BelowFamilyTaxonomy')
        allow(BriefSummary::Sentences::I18n::BelowFamilyTaxonomy).to receive(:new) { taxonomy_sentence }

        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:family_or_above?) { false }
        allow(page).to receive(:below_family?) { true }

        summary = BriefSummary::OtherLanguages.new(page, nil, :en)

        expect(summary.sentences).to include(taxonomy_sentence)
      end
    end
  end
end
