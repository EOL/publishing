require 'rails_helper'

RSpec.describe('Reconciliation::TaxonEntity') do
  let(:valid_page) { instance_double('Page') }
  let(:page_id) { 1234 }
  let(:page_name) { '<page name>' }

  before do
    allow(valid_page).to receive(:id) { page_id }
    allow(valid_page).to receive(:scientific_name_string) { page_name }
  end

  describe '#new' do
    context 'when page is nil' do
      let(:page) { nil }

      it { expect { Reconciliation::TaxonEntity.new(page) }.to raise_error(ArgumentError) }
    end

    context 'when page is not nil' do
      it { expect { Reconciliation::TaxonEntity.new(valid_page) }.to_not raise_error }
    end
  end

  describe '#to_h' do
    subject(:entity) { Reconciliation::TaxonEntity.new(valid_page) }

    it { expect(entity.to_h).to eq({ 'id' => 'pages/1234', 'name' => page_name }) }
  end
end
