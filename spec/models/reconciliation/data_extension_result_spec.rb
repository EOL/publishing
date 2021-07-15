require 'rails_helper'

RSpec.describe('Reconciliation::DataExtensionResult') do
  def build_ancestor(id, name)
    node_ancestor = instance_double('NodeAncestor')
    node = instance_double('Node') 
    page = instance_double('Page')

    allow(node_ancestor).to receive(:ancestor) { node }
    allow(node).to receive(:page) { page }
    allow(page).to receive(:id) { id }
    allow(page).to receive(:scientific_name_string) { name }

    node_ancestor
  end

  describe('#to_h') do
    let(:query) { instance_double('Reconciliation::DataExtensionQuery') }
    let(:id1) { 'pages/1234' }
    let(:id2) { 'pages/4321' }
    let(:id_invalid) { 'foo' }
    let(:page1) { instance_double('Page') }
    let(:page2) { instance_double('Page') }
    let(:rank1) { instance_double('Page') }
    let(:rank2) { instance_double('Page') }

    let(:anc1) { build_ancestor(1, '<anc1 name>') }
    let(:anc2) { build_ancestor(2, '<anc2 name>') }
    let(:anc3) { build_ancestor(3, '<anc3 name>') }

    let(:page_hash) do
      {
        id1 => page1,
        id2 => page2,
        id_invalid => nil
      }
    end

    subject(:result) { Reconciliation::DataExtensionResult.new(query) }
    
    before do
      allow(query).to receive(:properties) do
        [
          Reconciliation::PropertyType::ANCESTOR,
          Reconciliation::PropertyType::RANK
        ]
      end
      allow(query).to receive(:page_hash) { page_hash }

      allow(page1).to receive(:rank) { rank1 }
      allow(page2).to receive(:rank) { rank2 }
      allow(rank1).to receive(:human_treat_as) { nil }
      allow(rank2).to receive(:human_treat_as) { 'rank2' }

      allow(page1).to receive(:node_ancestors) { [anc1, anc2] }
      allow(page2).to receive(:node_ancestors) { [anc3] }
    end

    it do 
      expect(result.to_h).to eq({
        id1 => {
          'rank' => [],
          'ancestor' => [
            { 'id' => 'pages/1', 'name' => '<anc1 name>' },
            { 'id' => 'pages/2', 'name' => '<anc2 name>' }
          ]
        },
        id2 => {
          'rank' => [{ 'str' => 'rank2' }],
          'ancestor' => [
            { 'id' => 'pages/3', 'name' => '<anc3 name>' }
          ]
        },
        id_invalid => {
          'rank' => [],
          'ancestor' => []
        }
      })
    end
  end
end

