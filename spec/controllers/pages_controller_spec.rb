require 'rails_helper'

RSpec.describe PagesController do
  context "with a valid page" do
    let(:page) { create(:page) }
    let(:resource) { create(:resource) }
    let(:media) { double(Array, map: []) }

    before do
      allow(media).to receive_message_chain(:page, :per_page) { media }
      allow(TraitBank).to receive(:by_page) { [] }
      allow(TraitBank).to receive(:resources) { [resource] }
      allow_any_instance_of(Page).to \
        receive_message_chain(:media, :includes).
        and_return(media)
      allow_any_instance_of(Page).to \
        receive_message_chain(:media, :empty?).and_return(true)
    end

    describe "#breadcrumbs" do
      it "assigns page" do
        xhr :get, :breadcrumbs, page_id: page.id
        expect(assigns(:page)).to eq(page)
      end
    end

    describe "#data" do
      it "assigns page" do
        xhr :get, :data, page_id: page.id
        expect(assigns(:page)).to eq(page)
      end

      # We no longer want to do this here; we do it in the view...
      # it "assigns resources" do
      #   xhr :get, :data, page_id: page.id
      #   expect(assigns(:resources)).to eq([resource])
      # end
    end

    describe '#show' do
      it "assigns page" do
        get :show, id: page.id
        expect(assigns(:page)).to eq(page)
      end

      it "assigns page_title" do
        get :show, id: page.id
        expect(assigns(:page_title)).to eq(page.name)
      end

      it "assigns media" do
        get :show, id: page.id
        expect(assigns(:media)).to eq(media)
      end

      it "assigns associations" do
        get :show, id: page.id
        expect(assigns(:media)).to eq(media)
      end
    end
  end

  context "with a missing page" do
    let(:page_id) { Page.any? ? Page.last.id + 1 : 1 }
    describe "#show" do
      it "raises RecordNotFound" do
        expect { get :show, id: page_id }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    describe "#breadcrumbs" do
      it "raises a 404" do
        xhr :get, :breadcrumbs, page_id: page_id
        expect(response.status).to eq(404)
      end
    end
  end
end
