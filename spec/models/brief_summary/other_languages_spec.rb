require 'rails_helper'

RSpec.describe 'BriefSummary::OtherLanguages' do
  describe '#sentences' do
    context 'when page is family_or_above?' do
      it 'includes a FamilyAndAboveTaxonomy sentence' do
        taxonomy_sentence = instance_double('BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy')

        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:family_or_above?) { true }
        allow(BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy).to receive(:new) { taxonomy_sentence }

        summary = BriefSummary::OtherLanguages.new(page, nil, :en)

        expect(summary.sentences).to include(taxonomy_sentence)
      end
    end

    context 'when page is below_family?' do
      it 'includes a BelowFamilyTaxonomy sentence' do
        taxonomy_sentence = instance_double('BriefSummary::Sentences::I18n::BelowFamilyTaxonomy')

        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:family_or_above?) { false }
        allow(page).to receive(:below_family?) { true }
        allow(BriefSummary::Sentences::I18n::BelowFamilyTaxonomy).to receive(:new) { taxonomy_sentence }

        summary = BriefSummary::OtherLanguages.new(page, nil, :en)

        expect(summary.sentences).to include(taxonomy_sentence)
      end
    end
  end
end
