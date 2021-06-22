require 'rails_helper'

RSpec.describe 'BriefSummary::OtherLanguages' do
  describe '#sentences' do
    context 'when rank is above family' do
      it 'returns the expected Array of sentences' do
        taxonomy_sentence = instance_double('BriefSummary::Sentences::I18n::AboveFamilyTaxonomy')

        page = instance_double('BriefSummary::PageDecorator')
        allow(page).to receive(:family_or_above?) { true }
        allow(BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy).to receive(:new) { taxonomy_sentence }

        summary = BriefSummary::OtherLanguages.new(page, nil, :en)

        expect(summary.sentences).to eql([taxonomy_sentence])
      end
    end
  end
end
