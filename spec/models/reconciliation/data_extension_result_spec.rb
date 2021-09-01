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

    context('when query has multiple pages and properties') do
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

      let(:prop_ancestor) { instance_double('Reconciliation::Property') }
      let(:prop_rank) { instance_double('Reconciliation::Property') }
      let(:setting_limit) { instance_double('Reconciliation::PropertySetting') }

      subject(:result) { Reconciliation::DataExtensionResult.new(query) }
      
      before do
        allow(query).to receive(:properties) do
          [
            prop_ancestor,
            prop_rank
          ]
        end
        allow(query).to receive(:page_hash) { page_hash }

        allow(page1).to receive(:rank) { rank1 }
        allow(page2).to receive(:rank) { rank2 }
        allow(rank1).to receive(:human_treat_as) { nil }
        allow(rank2).to receive(:human_treat_as) { 'rank2' }

        allow(page1).to receive(:node_ancestors) { [anc1, anc2, anc3] }
        allow(page2).to receive(:node_ancestors) { [anc3] }

        allow(prop_ancestor).to receive(:type) { Reconciliation::PropertyType::ANCESTOR }
        allow(prop_rank).to receive(:type) { Reconciliation::PropertyType::RANK }
        allow(prop_rank).to receive(:settings) { [] }
        #allow(prop_ancestor).to receive(:settings) { [setting_limit] }
        allow(prop_ancestor).to receive(:settings) { [] }
        allow(setting_limit).to receive(:type) { Reconciliation::PropertySettingType::LIMIT }
        allow(setting_limit).to receive(:value) { 2 }
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

    #context 'when request is for conservation_status' do
    #  let(:page_id) { 'pages/1234' }
    #  let(:page) { instance_double('Page') }
    #  let(:term_node) { class_double('TermNode').as_stubbed_const }
    #  let(:predicate) { instance_double('TermNode') }
    #  let(:object) { instance_double('TermNode') }
    #  let(:trait) { instance_double('Trait') }
    #  

    #  before do
    #    allow(query).to receive(:properties) { [Reconciliation::PropertyType::CONSERVATION_STATUS] }
    #    allow(query).to receive(:page_hash) { { page_id => page } }
    #    allow(term_node).to receive(:find_by_alias).with('conservation_status') { predicate }
    #    allow(page).to receive(:first_trait_for_predicate).with(predicate) { trait }
    #  end
    #end
    
    context 'when request is for extinction_status' do
      let(:page_id) { 'pages/1234' }
      let(:page) { instance_double('Page') }
      let(:decorator_class) { class_double('BriefSummary::PageDecorator').as_stubbed_const }
      let(:decorator) { instance_double('BriefSummary::PageDecorator') }

      subject(:result) { Reconciliation::DataExtensionResult.new(query) }

      before do
        allow(query).to receive(:properties) { [Reconciliation::PropertyType::EXTINCTION_STATUS] }
        allow(query).to receive(:page_hash) { { page_id => page } }
        allow(decorator_class).to receive(:new).with(page, nil) { decorator }
      end

      context 'when extinct?' do
        before { allow(decorator).to receive(:extinct?) { true } }

        it do
          expect(result.to_h).to eq({
            page_id => { 
              'extinction_status' => 'extinct'
            }
          })
        end
      end

      context 'when not extinct?' do
        before { allow(decorator).to receive(:extinct?) { false } }

        it do
          expect(result.to_h).to eq({
            page_id => { 
              'extinction_status' => 'extant'
            }
          })
        end
      end
    end
  end
end

