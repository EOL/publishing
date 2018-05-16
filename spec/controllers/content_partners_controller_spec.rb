require 'rails_helper'

RSpec.describe ContentPartnersController do
  render_views
  context "creating new content partner" do
    let(:user) { create(:user) }

    it "should re-render new template on failed save" do
      post :create ,content_partner: FactoryGirl.attributes_for(:content_partner , :invalid) 
      expect(response.body).to render_template(:new)
    end
    
    it "should redirect to content partner on successful create" do
      allow(controller).to receive(:current_user) { user }
      ContentPartnerApi.stub(:add_content_partner?){1}
      post :create ,content_partner: FactoryGirl.attributes_for(:content_partner ) 
      expect(flash[:notice]).to eq I18n.t :successfuly_created_content_partner
      response.should redirect_to controller: 'content_partners', action: 'show', id: 1
    end
    
    it "should redirect to content partner on successful create" do
      allow(controller).to receive(:current_user) { user }
      ContentPartnerApi.stub(:add_content_partner?){1}
      post :create ,content_partner: FactoryGirl.attributes_for(:content_partner, :default_logo ) 
      expect(flash[:notice]).to eq I18n.t :successfuly_created_content_partner
      response.should redirect_to controller: 'content_partners', action: 'show', id: 1
    end
    
    it "should re-render new template on failed update scheduler or storage layer" do
      allow(controller).to receive(:current_user) { user }
      ContentPartnerApi.stub(:add_content_partner?){nil}
      post :create ,content_partner: FactoryGirl.attributes_for(:content_partner ) 
      expect(flash[:notice]).to eq I18n.t :error_in_connection
    end
    
  end
  
  context "update content partner" do
    it "should re-render edit template on failed save" do
      put :update ,content_partner: FactoryGirl.attributes_for(:content_partner , :invalid) , id: 1
      expect(response.body).to render_template(:edit)
    end
    
    it "should redirect to content partner on successful update" do
      ContentPartnerApi.stub(:update_content_partner?){1}
      put :update ,content_partner: FactoryGirl.attributes_for(:content_partner ) , id: 1
      expect(flash[:notice]).to eq I18n.t :Successfully_updated_content_partner
      response.should redirect_to controller: 'content_partners', action: 'show', id: 1
    end
    
        
    it "should re-render edit template on failed update scheduler or storage layer" do
      ContentPartnerApi.stub(:update_content_partner?){nil}
      put :update ,content_partner: FactoryGirl.attributes_for(:content_partner ) , id: 1
      expect(flash[:notice]).to eq I18n.t :error_in_connection
    end
    
  end
end