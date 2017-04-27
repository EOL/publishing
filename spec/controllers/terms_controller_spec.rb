require 'rails_helper'

RSpec.describe TermsController do
  let(:trait) do
    { predicate: {
        name: "extinction status",
        is_hidden_from_glossary: false,
        definition: "living today or not",
        is_hidden_from_overview: false,
        uri: "http://eol.org/schema/terms/ExtinctionStatus" },
      literal: "extant",
      id: "trait:17:d7cf04b725e0c2f140489261ef365952"
    }
  end
  let(:resource) { create(:resource) }
  let(:page_measured) { create(:page) }
  let(:page_term) { create(:page) }
  let(:page_literal) { create(:page) }
  let(:units) { { uri: "http://units.com/unit/inch", name: "inch",
    definition: "inching" } }
  let(:term) { { uri: "http://terms.com/size/big", name: "big",
    definition: "large" } }
  let(:glossary) { { units[:uri] => units, term[:uri] => term } }
  let(:grouped_traits) do
    [ { page_id: page_measured.id, measurement: "657", units: units[:uri],
        resource_id: resource.id },
      { page_id: page_term.id, term: term[:uri], resource_id: resource.id },
      { page_id: page_literal.id, literal: "literal trait value",
        resource_id: resource.id }
    ]
  end
  let(:pages) { [page_measured, page_term, page_literal] }

  before do
    allow(TraitBank).to receive(:term_as_hash) { trait[:predicate] }
    allow(TraitBank).to receive(:by_predicate) { grouped_traits }
    # allow(TraitBank).to receive(:glossary) { glossary }
    allow(TraitBank).to receive(:resources) { [resource] }
  end

  describe '#show' do
    before do
      get :show, uri: trait[:predicate][:uri]
    end

    it { expect(assigns(:term)[:uri]).to eq(trait[:predicate][:uri]) }
    # it { expect(assigns(:glossary)).to eq(glossary) }
    it { expect(assigns(:resources)).to eq([resource]) }
    it { expect(assigns(:grouped_traits)).to eq(grouped_traits) }

    it "assigns pages" do
      pages.each do |page|
        expect(assigns(:pages).values).to include(page)
      end
    end
  end

  # TODO: come back to this; it's disabled for now.
  # describe '#clade filter' do
  #   context 'empty result' do
  #     before do
  #       get :clade_filter, format: :js, uri: trait[:predicate][:uri], clade_name: page_term.name
  #     end
  #
  #     it { expect(assigns(:glossary)).to eq(nil) }
  #     it { expect(assigns(:resources)).to eq(nil) }
  #     it { expect(assigns(:grouped_traits)).to eq(nil) }
  #   end
  #
  #   context 'non-empty result' do
  #
  #     let(:solr_pages) { double("Sunspot::Search", results: pages) }
  #     let(:returned_traits) {[{ page_id: page_measured.id, measurement: "657",
  #         units: units[:uri], resource_id: resource.id }]}
  #
  #     before do
  #       allow(Page).to receive(:search) { solr_pages }
  #       allow(TraitBank).to receive(:get_clade_traits) { returned_traits }
  #       get :clade_filter, format: :js, uri: trait[:predicate][:uri], clade_name: trait[:predicate][:name]
  #     end
  #
  #     it { expect(assigns(:glossary)).to eq(glossary) }
  #     it { expect(assigns(:resources)).to eq([resource]) }
  #     it { expect(assigns(:grouped_traits)).to eq(returned_traits) }
  #   end
  # end

end
