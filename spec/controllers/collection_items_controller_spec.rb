require 'rails_helper'

RSpec.describe CollectionItemsController do
  describe "#new" do
    let(:item) { create(:medium) }

    let!(:collection_with_item) do
      collection = create(:collection)
      create(:collection_item, item: item, collection: collection)
      collection
    end

    before { get :new, item_type: "Medium", item_id: item.id }

    it { expect(assigns(:collection_item).item_id).to eq(item.id) }
    it { expect(assigns(:collection_item).item_type).to eq("Medium") }
    it { expect(assigns(:item)).to eq(item) }
    it { expect(assigns(:collection)).to be_a(Collection) }
    it { expect(assigns(:bad_collection_ids)).to include(collection_with_item.id) }
  end

  describe "#create" do
    let(:item) { create(:medium) }
    let(:collection) { create(:collection) }

    let(:collection_item_params) do
      attributes_for(:collection_item, item_id: item.id, item_type: "Medium",
        collection_id: collection.id)
    end

    before do
      post :create, collection_item: collection_item_params
    end

    it { expect(assigns(:collection_item).item_type).to eq("Medium") }
    it { expect(assigns(:collection_item).item_id).to eq(item.id) }
    it { expect(assigns(:collection_item).collection_id).to eq(collection.id) }
    it { expect(flash[:notice]).to match(collection.name) }
    it { expect(flash[:notice]).to match(item.name) }
    it { expect(response).to redirect_to(item) }
  end
end
