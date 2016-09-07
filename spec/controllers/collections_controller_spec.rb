require 'rails_helper'

RSpec.describe CollectionsController do
  let(:user) { create(:user) }
  let(:page) { create(:page) }

  before(:each) do
    allow(controller).to receive(:current_user) { user }
  end

  context "with NO collection item" do
    let(:collection) { build(:collection) }

    it "redirects to collection" do
      post :create, collection: collection.attributes
      created_collection = Collection.last
      expect(response).to redirect_to(created_collection)
    end

    it "adds a flash message" do
      post :create, collection: collection.attributes
      expect(flash[:notice]).to match /new collection "#{collection.name}"/
    end
  end

  context "with a collection item" do
    let(:collection_attributes) do
      attributes_for(:collection).
        merge(collection_items_attributes:
          { "0" => { item_id: page.id, item_type: page.class.to_s } })
    end

    describe '#create (signed in)' do

      it "redirects to collected item" do
        post :create, collection: collection_attributes
        expect(response).to redirect_to(page)
      end

      it "adds a flash message" do
        post :create, collection: collection_attributes
        expect(flash[:notice]).to match /new collection/
        expect(flash[:notice]).to match /#{page.collect_as}/
      end
    end
  end
end
