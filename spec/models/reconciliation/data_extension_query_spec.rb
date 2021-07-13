require 'rails_helper'

require 'reconciliation/data_extension_query'

RSpec.describe 'Reconciliation::DataExtensionQuery' do
  describe '#new' do
    let(:ids) { ['page-1234', 'page-321'] }
    let(:properties) { [{ 'id' => 'rank' }] }
    let(:prop_type) { class_double('Reconciliation::PropertyType').as_stubbed_const }

    before do
      allow(prop_type).to receive(:id_valid?) { false }
      allow(prop_type).to receive(:id_valid?).with('rank') { true }
    end

    context 'when raw_query is valid' do
      let(:raw_query) do
        {
          'ids' => ids,
          'properties' => properties
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to_not raise_error }
    end

    context "when raw_query is missing 'ids' property" do
      let(:raw_query) do 
        {
          'properties' => properties
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(TypeError) }
    end

    context "when raw_query is missing 'properties' property" do
      let(:raw_query) do 
        {
          'ids' => ids
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(TypeError) }
    end

    context "when there is an invalid 'properties' value" do
      let(:raw_query) do
        {
          'ids' => ids,
          'properties' => [{ 'id' => 'bad_id' }]
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(TypeError) }
    end
  end
end
