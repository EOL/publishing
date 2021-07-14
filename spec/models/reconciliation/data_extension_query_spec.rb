require 'rails_helper'

require 'reconciliation/data_extension_query'

RSpec.describe 'Reconciliation::DataExtensionQuery' do
  let(:taxon_entity_resolver) { class_double('Reconciliation::TaxonEntityResolver').as_stubbed_const }
  let(:ids) { ['page-1234', 'page-321'] }
  let(:properties) { [{ 'id' => 'rank' }] }
  let(:valid_query) do 
    {
      'ids' => ids,
      'properties' => properties
    }
  end
  let(:prop_type) { class_double('Reconciliation::PropertyType').as_stubbed_const }
  let(:prop_rank) { instance_double('Reconciliation::PropertyType') }
  let(:resolver_result) { instance_double('Hash') }

  before do
    allow(prop_type).to receive(:id_valid?) { false }
    allow(prop_type).to receive(:id_valid?).with('rank') { true }
    allow(prop_type).to receive(:for_id).with('rank') { prop_rank }
    allow(taxon_entity_resolver).to receive(:resolve_ids).with(ids) { resolver_result }
  end

  describe '#new' do

    context 'when raw_query is valid' do
      it { expect { Reconciliation::DataExtensionQuery.new(valid_query) }.to_not raise_error }

      context 'when TaxonEntityResolver raises an ArgumentError' do
        before do
          allow(taxon_entity_resolver).to receive(:resolve_ids).with(ids).and_raise(ArgumentError)
        end

        it { expect { Reconciliation::DataExtensionQuery.new(valid_query) }.to raise_error(ArgumentError) }
      end
    end

    context "when raw_query is missing 'ids' property" do
      let(:raw_query) do 
        {
          'properties' => properties
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(ArgumentError) }
    end

    context "when 'ids' is not an Array" do
      let(:raw_query) do 
        {
          'properties' => properties,
          'ids' => 'page-1234'
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

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(ArgumentError) }
    end

    context "when there is an invalid 'properties' value" do
      let(:raw_query) do
        {
          'ids' => ids,
          'properties' => [{ 'id' => 'bad_id' }]
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(ArgumentError)}
    end

    context "when  'properties' is not an Array" do
      let(:raw_query) do
        {
          'ids' => ids,
          'properties' => true
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(TypeError) }
    end

    context "when a 'properties' value doesn't have an id property" do
      let(:raw_query) do
        {
          'ids' => ids,
          'properties' => [{ metadata: ['abc'] }]
        }
      end

      it { expect { Reconciliation::DataExtensionQuery.new(raw_query) }.to raise_error(ArgumentError) }
    end
  end

  describe '#page_hash' do
    subject(:query) { Reconciliation::DataExtensionQuery.new(valid_query) }

    it { expect(query.page_hash).to eq(resolver_result) }
  end

  describe '#properties' do
    subject(:query) { Reconciliation::DataExtensionQuery.new(valid_query) }

    it { expect(query.properties).to eq([prop_rank]) }
  end
end

