require 'rails_helper'

RSpec.describe SearchController do
  let(:page) { create(:page) }

  before do
    allow(Page).to receive(:search) { :fake_reuslts }
  end

  describe '#show' do
    it "assigns page" do
      get :search, q: "query"
      expect(assigns(:pages)).to eq(:fake_reuslts)
    end

    it "assigns query string" do
      get "search", q: "this_string"
      expect(assigns(:q)).to eq("this_string")
    end

    it "runs a name search" do
      get :search, q: "query"
      expect(Page).to have_received(:search)
    end
  end
end
