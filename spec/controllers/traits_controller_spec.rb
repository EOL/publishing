require 'rails_helper'

RSpec.describe TraitsController do
  let(:trait) { create(:uri) }
  let(:page_measured) { create(:page) }
  let(:page_term) { create(:page) }
  let(:page_literal) { create(:page) }
  let(:units) { create(:uri) }
  let(:term) { create(:uri) }
  let(:glossary) { { units.uri => units, term.uri => term } }
  let(:traits) do
    [ { page_id: page_measured.id, measurement: "657", units: units.uri },
      { page_id: page_term.id, term: term.uri },
      { page_id: page_literal.id, literal: "literal trait value" }
    ]
  end
  let(:pages) { [page_measured, page_term, page_literal] }

  before do
    allow(TraitBank).to receive(:by_predicate) { traits }
    allow(TraitBank).to receive(:glossary) { glossary }
  end

  describe '#show' do
    it "assigns uri" do
      get :show, id: trait.id
      expect(assigns(:uri)).to eq(trait)
    end

    it "assigns traits" do
      get :show, id: trait.id
      expect(assigns(:traits)).to eq(traits)
    end

    it "assigns pages" do
      get :show, id: trait.id
      pages.each do |page|
        expect(assigns(:pages).values).to include(page)
      end
    end

    it "assigns glossary" do
      get :show, id: trait.id
      expect(assigns(:glossary)).to eq(glossary)
    end
  end
end
