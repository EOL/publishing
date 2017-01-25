require 'rails_helper'

RSpec.describe SearchController do


  let(:page) { create(:page) }
  let(:pages) { double("Sunspot::Search", results: [page], empty: false) }
  let(:collections) { double("Sunspot::Search", results: [], empty: true) }
  let(:media) { double("Sunspot::Search", results: [], empty: true) }
  let(:users) { double("Sunspot::Search", results: [], empty: true) }
  let(:suggestions) { double("Sunspot::Search", results: [SearchSuggestion.create(object_term: "something", match: "match")]) }

  before do
    allow(Page).to receive(:search) { pages }
    allow(Collection).to receive(:search) { collections }
    allow(Medium).to receive(:search) { media }
    allow(User).to receive(:search) { users }
    allow(SearchSuggestion).to receive(:search) {suggestions}
  end

  describe "#show" do

    context "when requesting all results" do
      before { get :search, q: "query", except: "object_terms" }
      it { expect(assigns(:pages)).to eq(pages) }
      it { expect(assigns(:collections)).to eq(collections) }
      it { expect(assigns(:media)).to eq(media) }
      it { expect(assigns(:users)).to eq(users) }
      it { expect(assigns(:empty)).to eq(false) }
      it { expect(assigns(:q)).to eq("query") }
      it { expect(Page).to have_received(:search) }
    end

    context "when only requesting pages" do
      before { get :search, q: "query", only: "pages" }
      it { expect(Collection).not_to have_received(:search) }
    end

    context "when requesting all except collections" do
      before { get :search, q: "query", except: ["collections", "object_terms"] }
      it { expect(Collection).not_to have_received(:search) }
    end
  end
end
