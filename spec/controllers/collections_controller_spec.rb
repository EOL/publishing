require 'rails_helper'

RSpec.describe CollectionsController do
  describe "#new" do
    let(:user) { create(:user) }
    let(:image) { create(:image) }

    before do
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
            { "0" => { item_id: image.id, item_type: image.class.to_s } })
      end

      describe '#create (signed in)' do
        it "redirects to collected item" do
          post :create, collection: collection_attributes
          expect(response).to redirect_to(image)
        end

        it "adds a flash message" do
          post :create, collection: collection_attributes
          expect(flash[:notice]).to match /new collection/
          expect(flash[:notice]).to match /#{image.name}/
        end
      end
    end

    context "with a collected page" do
      let(:page) { create(:page) }
      let(:collection_attributes) do
        attributes_for(:collection).
          merge(collected_pages_attributes:
            { "0" => { page_id: page.id } })
      end

      describe '#create (signed in)' do
        it "redirects to collected page" do
          post :create, collection: collection_attributes
          expect(response).to redirect_to(page)
        end

        it "adds a flash message" do
          post :create, collection: collection_attributes
          expect(flash[:notice]).to match /new collection/
          expect(flash[:notice]).to match /#{page.name}/
        end
      end
    end
  end

  describe "#show" do
    let(:collection) { create(:collection) }

    before { get :show, id: collection.id }

    it { expect(assigns(:collection)).to eq(collection) }
  end

  describe "#edit" do
    let(:collection) { create(:collection) }

    it "assigns collection" do
      get :edit, id: collection.id
      expect(assigns(:collection)).to eq(collection)
    end
  end

  describe "#update" do
    let(:collection) { create(:collection) }
    let(:user) { create(:user) }

    # NOTE: Policy specs should be used to cover authorization failures.

    context "with correct setup" do
      before do
        allow(controller).to receive(:current_user) { user }
        collection.users << user
        put :update, id: collection.id, collection: {
          name: "new name", description: "new description" }
        collection.reload
      end

      it { expect(response).to redirect_to(collection) }
      it { expect(assigns(:collection)).to eq(collection) }
      it { expect(collection.name).to eq("new name") }
      it { expect(collection.description).to eq("new description") }
      it { expect(flash[:notice]).to eq(I18n.t(:collection_updated)) }

    end

    context "with a failure" do
      it "redirects with flash" do
        allow(controller).to receive(:current_user) { user }
        collection.users << user
        attributes = collection.attributes
        attributes[:name] = ""
        put :update, id: collection.id, collection: attributes
        collection.reload
        expect(response).to render_template(:edit)
      end
    end
  end
end
