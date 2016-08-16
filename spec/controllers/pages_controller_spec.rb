require 'rails_helper'

RSpec.describe PagesController do
  let(:page) { create(:page) }
  let(:resource) { create(:resource) }

  before do
    allow(TraitBank).to receive(:by_page) { [] }
    allow(TraitBank).to receive(:resources) { [resource] }
  end

  describe '#show' do
    it "assigns page" do
      get :show, id: page.id
      expect(assigns(:page)).to eq(page)
    end
  end

  describe '#show' do
    it "assigns resources" do
      get :show, id: page.id
      expect(assigns(:resources)).to eq([resource])
    end
  end
end
