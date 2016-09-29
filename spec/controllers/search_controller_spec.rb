require 'rails_helper'

RSpec.describe SearchController do
  let(:page) { create(:page) }
  let(:fake_results) { double("Sunspot::Search", results: [], empty: true) }

  before do
    allow(Page).to receive(:search) { fake_results }
  end

  describe '#show' do
    before { get :search, q: "query" }
    it { expect(assigns(:pages)).to eq(fake_results) }
    it { expect(assigns(:q)).to eq("query") }
    it { expect(Page).to have_received(:search) }
  end
end
