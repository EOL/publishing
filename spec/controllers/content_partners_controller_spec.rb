require 'rails_helper'

RSpec.describe ContentPartnersController do
  render_views
  context "creating new content partner" do
    it "should re-render new template on failed save" do
      post :create ,content_partner: FactoryGirl.attributes_for(:content_partner , :invalid) 
      expect(response.body).to render_template(:new)
    end
  end
end