require 'rails_helper'

require 'reconciliation/data_extension_query'

RSpec.describe 'Reconciliation::DataExtensionQuery' do
  let(:taxon_entity_resolver) { class_double('Reconciliation::TaxonEntityResolver').as_stubbed_const }
  let(:ids) { ['page-1234', 'page-321'] }
  let(:limit) { 5 }
  let(:properties) do 
    [
      { 
        'id' => 'rank',
        'settings' => {
          'limit' => limit
        }
      }
    ] 
  end

  let(:valid_query) do 
    {
      'ids' => ids,
      'properties' => properties
    }
  end

  let(:prop_type) { class_double('Reconciliation::PropertyType').as_stubbed_const }
  let(:prop_rank) { instance_double('Reconciliation::PropertyType') }
  let(:resolver_result) { instance_double('Hash') }
  let(:prop_setting_class) { class_double('Reconciliation::PropertySetting').as_stubbed_const }
  let(:prop_setting) { instance_double('Reconciliation::PropertySetting') }
  let(:expected_includes) do 
    { native_node: [:rank, node_ancestors: { ancestor: :page }] }
  end

  before do
    allow(prop_type).to receive(:id_valid?) { false }
    allow(prop_type).to receive(:id_valid?).with('rank') { true }
    allow(prop_type).to receive(:for_id).with('rank') { prop_rank }
    allow(prop_setting_class).to receive(:new).with('limit', limit) { prop_setting }
    allow(taxon_entity_resolver).to receive(:resolve_ids).with(ids, includes: expected_includes) { resolver_result }
  end

  describe '#new' do

    context 'when raw_query is valid' do
      it { expect { Reconciliation::DataExtensionQuery.new(valid_query) }.to_not raise_error }

      context 'when TaxonEntityResolver raises an ArgumentError' do
        before do
          allow(taxon_entity_resolver).to receive(:resolve_ids).with(ids, includes: expected_includes).and_raise(ArgumentError)
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

    it do 
      properties = query.properties
      expect(properties.length).to eq(1)

      property = properties.first
      expect(property.type).to eq(prop_rank)

      settings = property.settings
      expect(settings.length).to eq(1)

      setting = settings.first
      expect(setting).to eq(prop_setting)
    end
  end
end

