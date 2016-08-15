require 'rails_helper'

RSpec.describe TraitsController do
  let(:trait) { create(:uri) }

  describe '#show' do
    it "assigns uri" do
      get :show, id: trait.id
      expect(assigns(:uri)).to eq(trait)
    end
  end
end
