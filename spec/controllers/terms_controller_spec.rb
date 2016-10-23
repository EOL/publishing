require 'rails_helper'

RSpec.describe TermsController do
  let(:term) { { name: "nom du term", uri: "http://a/term" } }
  let(:resource) { create(:resource) }
  let(:page_measured) { create(:page) }
  let(:page_term) { create(:page) }
  let(:page_literal) { create(:page) }
  let(:units) { { name: "units", uri: "http://a/unit" } }
  let(:object_term) { { name: "term", uri: "http://a/term" } }
  let(:glossary) { { units[:uri] => units, term[:uri] => term } }
  let(:grouped_traits) do
    [ { page_id: page_measured.id, measurement: "657", units: units,
        resource_id: resource.id },
      { page_id: page_term.id, term: term, resource_id: resource.id },
      { page_id: page_literal.id, literal: "literal term value",
        resource_id: resource.id }
    ]
  end
  let(:pages) { [page_measured, page_term, page_literal] }

  before do
    allow(TraitBank).to receive(:by_predicate) { grouped_traits }
    allow(TraitBank).to receive(:glossary) { glossary }
    allow(TraitBank).to receive(:resources) { [resource] }
    allow(TraitBank).to receive(:term_as_hash) { term }
    get :show, id: term[:uri]
  end

  describe '#show' do
    it { expect(assigns(:term)).to eq(term) }
    it { expect(assigns(:grouped_traits)).to eq(grouped_traits) }
    it { expect(assigns(:glossary)).to eq(glossary) }
    it { expect(assigns(:resources)).to eq([resource]) }

    it "assigns all pages" do
      pages.each do |page|
        expect(assigns(:pages).values).to include(page)
      end
    end
  end
end
