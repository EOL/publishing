require 'rails_helper'

RSpec.describe MediaController do
  describe "#show" do
    let(:medium) { create(:medium) }
    before { get :show, id: medium.id }
    it { expect(assigns(:medium)).to eq(medium) }
  end
end
