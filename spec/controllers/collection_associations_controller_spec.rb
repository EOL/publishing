require 'rails_helper'

RSpec.describe CollectionAssociationsController do
  describe "#new" do
    let(:item) { create(:collection) }

    let!(:collection_with_item) do
      collection = create(:collection)
      create(:collection_association, associated: item, collection: collection)
      collection
    end

    before { get :new, associated_id: item.id }

    it { expect(assigns(:collection_association).associated_id).to eq(item.id) }
    it { expect(assigns(:associated)).to eq(item) }
    it { expect(assigns(:collection)).to be_a(Collection) }
    it { expect(assigns(:bad_collection_ids)).to include(collection_with_item.id) }
  end

  describe "#create" do
    let(:item) { create(:collection) }
    let(:collection) { create(:collection) }

    let(:collection_association_params) do
      attributes_for(:collection_association, associated_id: item.id,
        collection_id: collection.id)
    end

    before do
      post :create, collection_association: collection_association_params
    end

    it { expect(assigns(:collection_association).associated_id).to eq(item.id) }
    it { expect(assigns(:collection_association).collection_id).to eq(collection.id) }
    it { expect(flash[:notice]).to match(collection.name) }
    it { expect(flash[:notice]).to match(item.name) }
    it { expect(response).to redirect_to(item) }
  end
end
