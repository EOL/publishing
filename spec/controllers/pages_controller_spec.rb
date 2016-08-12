require 'rails_helper'

RSpec.describe PagesController do
  let(:page) { create(:page) }

  describe '#show' do
    it "assigns page" do
      get :show, id: page.id
      expect(assigns(:page)).to eq(page)
    end
  end
end
