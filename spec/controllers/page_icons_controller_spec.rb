require 'rails_helper'

RSpec.describe PageIconsController do
  let(:page) { create(:page) }
  let(:image) { create(:image, name: "BurtImage") }
  let(:user) { create(:user) }
  let!(:page_content) { PageContent.create(page: page, content: image, source_page_id: page.id, resource_id: 1) }

  before do
    allow(controller).to receive(:current_user) { user }
  end

  describe "#create" do
    it "should create a Page Icon" do
      expect { post :create, page_id: page.id, medium_id: image.id }.
        to change(PageIcon, :count).by(1)
    end

    context "with proper arguments" do
      before do
        post :create, page_id: page.id, medium_id: image.id
      end

      it { expect(flash[:notice]).to match /BurtImage/ }
      it { expect(response).to redirect_to(page) }
    end
  end
end
