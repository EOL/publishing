require 'rails_helper'

RSpec.describe CollectionsController do
  let(:user) { create(:user) }
  let(:page) { create(:page) }
  let(:collection_attributes) do
    attributes_for(:collection).
      merge(collection_items_attributes:
        { "0" => { item_id: page.id, item_type: page.class.to_s } })
  end

  describe '#create (signed in)' do
    before(:each) do
      request.env["devise.mapping"] = Devise.mappings[:user]
      allow(request.env['warden']).to receive(:authenticate!) { user }
      allow(controller).to receive(:current_user) { user }
    end

    it "redirects to collected item" do
      post :create, collection: collection_attributes
      expect(response).to redirect_to(page)
    end

    it "adds a flash message" do
      post :create, collection: collection_attributes
      expect(flash[:notice]).to match /#{page.collect_as}/
    end
  end
end
