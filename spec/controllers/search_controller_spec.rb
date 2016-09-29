require 'rails_helper'

RSpec.describe SearchController do
  let(:page) { create(:page) }
  let(:pages) { double("Sunspot::Search", results: [], empty: true) }
  let(:collections) { double("Sunspot::Search", results: [], empty: true) }
  let(:media) { double("Sunspot::Search", results: [], empty: true) }
  let(:users) { double("Sunspot::Search", results: [], empty: true) }

  before do
    allow(Page).to receive(:search) { pages }
    allow(Collection).to receive(:search) { collections }
    allow(Medium).to receive(:search) { media }
    allow(User).to receive(:search) { users }
  end

  describe "#show" do
    context "when requesting all results" do
      before { get :search, q: "query" }
      it { expect(assigns(:pages)).to eq(pages) }
      it { expect(assigns(:collections)).to eq(collections) }
      it { expect(assigns(:media)).to eq(media) }
      it { expect(assigns(:users)).to eq(users) }
      it { expect(assigns(:empty)).to eq(true) }
      it { expect(assigns(:q)).to eq("query") }
      it { expect(Page).to have_received(:search) }
    end
    
    context "when only requesting pages" do
      before { get :search, q: "query", only: "pages" }
      it { expect(Collection).not_to have_received(:search) }
    end
  end
end
