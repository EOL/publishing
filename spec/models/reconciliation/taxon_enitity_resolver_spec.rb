require 'rails_helper'

RSpec.describe('Reconciliation::TaxonEntityResolver') do
  shared_examples 'resolver' do |method, param_proc|
    context('when id format is valid') do
      let(:id) { 'pages/1234' }
      let(:page_klass) { class_double('Page').as_stubbed_const }
      let(:page) { instance_double('Page') }

      context 'when page is found' do
        before do
          allow(page_klass).to receive(:find_by).with(id: 1234) { page }
        end

        it do 
          expect(Reconciliation::TaxonEntityResolver.send(
            method, 
            param_proc.call(id)
          )).to eq(page)
        end
      end

      context 'when page is not found' do
        before do
          allow(page_klass).to receive(:find_by).with(id: 1234) { nil }
        end

        it do 
          expect(Reconciliation::TaxonEntityResolver.send(
            method, 
            param_proc.call(id)
          )).to be_nil
        end
      end
    end

    context 'when id format is invalid' do
      let(:id) { 'something_else/1234' }

      it do 
        expect(Reconciliation::TaxonEntityResolver.send(
          method, 
          param_proc.call(id)
        )).to be_nil
      end
    end

    context 'when id is not a String' do
      let(:id) { 1234 }

      it do
        expect(Reconciliation::TaxonEntityResolver.send(
            method, 
            param_proc.call(id)
        )).to be_nil
      end
    end
  end

  describe('.resolve_id') do
    it_behaves_like 'resolver', :resolve_id, lambda { |id| id }
  end

  describe('.resolve_hash') do
    context 'when hash has id attribute' do
      it_behaves_like 'resolver', :resolve_hash, lambda { |id| { 'id' => id } }
    end

    context "when hash doesn't have id attribute" do
      let(:hash) { { 'foo' => 'bar' } }

      it { expect(Reconciliation::TaxonEntityResolver.resolve_hash(hash)).to be_nil }
    end
  end

  describe('.resolve_ids') do
    context 'when ids is empty' do
      let(:ids) { [] }

      it { expect(Reconciliation::TaxonEntityResolver.resolve_ids(ids)).to eq({}) }
    end

    context 'when ids is not empty' do
      let(:page_klass) { class_double('Page').as_stubbed_const }

      context 'when ids contains a nil value' do
        let(:ids) do
          [
            'pages/1234',
            nil,
            'pages/456'
          ]
        end

        it { expect { Reconciliation::TaxonEntityResolver.resolve_ids(ids) }.to raise_error(ArgumentError) }
      end

      context 'when ids is valid' do
        let(:ids) do
          [
            'pages/1234',
            72341,
            'pages/321',
            'pages/789',
            'taxa/333'
          ]
        end
        let(:page1) { instance_double('Page') }
        let(:page1_id) { 1234 }
        let(:page2) { instance_double('Page') }
        let(:page2_id) { 321 }

        before do
          allow(page_klass).to receive(:where).with(id: [page1_id, page2_id, 789]) { [page1, page2] }
          allow(page1).to receive(:id) { page1_id }
          allow(page2).to receive(:id) { page2_id }
        end

        it do 
          expect(Reconciliation::TaxonEntityResolver.resolve_ids(ids)).to eq({
            'pages/1234' => page1,
            72341 => nil,
            'pages/321' => page2,
            'pages/789' => nil,
            'taxa/333' => nil
          })
        end
      end

      context "when 'includes' option is set" do
        let(:ids) { [ 'pages/1234' ] }
        let(:page) { instance_double('Page') }
        let(:page_id) { 1234 }
        let(:includes) { instance_double('Array') }
        let(:includes_result) { double('query_proxy') }

        before do
          allow(page_klass).to receive(:includes).with(includes) { includes_result }
          allow(includes_result).to receive(:where).with(id: [page_id]) { [page] }
          allow(page).to receive(:id) { page_id }
        end

        it do
          expect(Reconciliation::TaxonEntityResolver.resolve_ids(ids, includes: includes)).to eq({
            'pages/1234' => page
          })
        end
      end
    end
  end
end

