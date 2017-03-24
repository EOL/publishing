require 'rails_helper'

RSpec.describe PagesController do
  context "with a valid page" do
    let(:page) { create(:page) }
    let(:resource) { create(:resource) }

    before do
      allow(TraitBank).to receive(:by_page) { [] }
      allow(TraitBank).to receive(:resources) { [resource] }
      allow_any_instance_of(Page).to \
        receive_message_chain(:media, :includes, :page, :per).
        and_return([])
    end

    describe '#show' do
      it "assigns page" do
        get :show, id: page.id
        expect(assigns(:page)).to eq(page)
      end

      it "assigns resources" do
        get :show, id: page.id
        expect(assigns(:resources)).to eq([resource])
      end

      it "assigns page_title" do
        get :show, id: page.id
        expect(assigns(:page_title)).to eq(page.name)
      end

      it "assigns media" do
        get :show, id: page.id
        expect(assigns(:media)).to eq([])
      end

      it "assigns associations" do
        get :show, id: page.id
        expect(assigns(:media)).to eq([])
      end
    end
  end

  context "with a missing page" do
    let(:page_id) { Page.any? ? Page.last.id + 1 : 1 }
    describe "#show" do
      it "raises a 404" do
        get :show, id: page_id
        expect(response.status).to eq(404)
      end
    end
  end
end
