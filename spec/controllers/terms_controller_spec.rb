require 'rails_helper'

RSpec.describe TermsController do
  let(:data) do
    { predicate: {
        name: "extinction status",
        is_hidden_from_glossary: false,
        definition: "living today or not",
        is_hidden_from_overview: false,
        uri: "http://eol.org/schema/terms/ExtinctionStatus" },
      literal: "extant",
      id: "data:17:d7cf04b725e0c2f140489261ef365952"
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
  let(:grouped_data) do
    [ { page_id: page_measured.id, measurement: "657", units: units[:uri],
        resource_id: resource.id },
      { page_id: page_term.id, term: term[:uri], resource_id: resource.id },
      { page_id: page_literal.id, literal: "literal data value",
        resource_id: resource.id }
    ]
  end
  let(:pages) { [page_measured, page_term, page_literal] }

  before do
    allow(TraitBank).to receive(:term_as_hash) { data[:predicate] }
    allow(TraitBank).to receive(:term_search).and_return(grouped_data, grouped_data.size)
    allow(TraitBank).to receive(:resources) { [resource] }
  end

  describe '#show' do
    before do
      get :show, uri: data[:predicate][:uri]
    end

    it { expect(assigns(:term)[:uri]).to eq(data[:predicate][:uri]) }
    # it { expect(assigns(:glossary)).to eq(glossary) }
    it { expect(assigns(:resources)).to eq([resource]) }
    it { expect(assigns(:grouped_data)).to eq(grouped_data) }

    it "assigns pages" do
      pages.each do |page|
        expect(assigns(:pages).values).to include(page)
      end
    end
  end
end
