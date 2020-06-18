require 'rails_helper'

def verify_search_results(actual, orig, deco_klazz)
  expect(actual).to be_decorated_with(SearchResultsDecorator)
  expect(actual.length).to equal(orig.length)

  actual.each_with_index do |item, i|
    expect(item).to be_decorated_with(deco_klazz)
    expect(item).to eql(orig[i])
  end
end

RSpec.describe SearchController do


  let(:page) { create(:page) }
  let(:pages) { fake_search_results([page]) }
  let(:collections) { fake_search_results([]) }
  let(:media) { fake_search_results([]) }
  let(:users) { fake_search_results([]) }
  let(:suggestions) { fake_search_results([SearchSuggestion.create(object_term: "something", match: "match")]) }

  before do
    allow(Page).to receive(:search) { pages }
    allow(Collection).to receive(:search) { collections }
    allow(User).to receive(:search) { users }
    allow(SearchSuggestion).to receive(:search) { [] }
    allow(Searchkick).to receive(:search) { media } # NOTE: Media uses multi-index search
    allow(TraitBank).to receive(:search_object_terms) { [] }
    allow(TraitBank).to receive(:count_object_terms) { 0 }
    allow(Searchkick).to receive(:multi_search) { }
  end

  describe "#show" do

    context "when requesting all results" do
      before { get :search, q: "query" }
      it "assigns @pages" do
        verify_search_results(assigns(:pages), pages, PageSearchDecorator)
      end

      it "assigns @collections" do
        verify_search_results(assigns(:collections), collections, CollectionSearchDecorator)
      end

      it "assigns @images" do
        verify_search_results(assigns(:images), media, ImageSearchDecorator)
      end

      it "assigns @videos" do
        verify_search_results(assigns(:videos), media, VideoSearchDecorator)
      end

      it "assigns @sounds" do
        verify_search_results(assigns(:sounds), media, SoundSearchDecorator)
      end

      it "assigns @users" do
        verify_search_results(assigns(:users), users, UserSearchDecorator)
      end

      it { expect(assigns(:q)).to eq("query") }
      it { expect(Page).to have_received(:search) }
    end

    context "when only requesting pages" do
      before { get :search, q: "query", only: "pages" }
      it { expect(Collection).not_to have_received(:search) }
    end
  end
end
