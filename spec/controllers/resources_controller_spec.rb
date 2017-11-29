require 'rails_helper'

RSpec.describe ContentPartners::ResourcesController do
  render_views
  context "creating new resource" do

    it "should redirect to resource on successful url" do
      ResourceApi.stub(:add_resource?){1}
      post :create ,resource: FactoryGirl.attributes_for(:resource , :valid_url) , content_partner_id: 1
      expect(flash[:notice]).to eq I18n.t :successfuly_created_resource
      response.should redirect_to controller: 'resources', action: 'show', id: 1
    end

    it "should redirect to resource on successful file upload" do
      ResourceApi.stub(:add_resource?){1}
      post :create ,resource: FactoryGirl.attributes_for(:resource , :valid_file) , content_partner_id: 1
      expect(flash[:notice]).to eq I18n.t :successfuly_created_resource
      response.should redirect_to controller: 'resources', action: 'show', id: 1
    end

    it "should re-render new template on failed url" do
      ResourceApi.stub(:add_resource?){1}
      post :create ,resource: FactoryGirl.attributes_for(:resource , :invalid_url) , content_partner_id: 1
      #expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:new)
    end

    it "should re-render new template on failed file upload" do
      ResourceApi.stub(:add_resource?){1}
      post :create ,resource: FactoryGirl.attributes_for(:resource , :invalid_file) , content_partner_id: 1
      #expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:new)
    end

    it "should re-render new template on failed save" do
      ResourceApi.stub(:add_resource?){1}
      post :create ,resource: FactoryGirl.attributes_for(:resource , :invalid) , content_partner_id: 1
      #expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:new)
    end
    
    it "should re-render new template on failed add to scheduler or storage layer" do
      ResourceApi.stub(:add_resource?){nil}
      post :create ,resource: FactoryGirl.attributes_for(:resource , :valid_file) , content_partner_id: 1
      expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:new)
    end
  end

  context "creating updating resource" do

    it "should redirect to resource on successful url" do
      ResourceApi.stub(:update_resource?){1}
      put :update ,resource: FactoryGirl.attributes_for(:resource , :valid_url) , content_partner_id: 1 , id: 1
      expect(flash[:notice]).to eq I18n.t :successfuly_updated_resource
      response.should redirect_to controller: 'resources', action: 'show', id: 1
    end

    it "should redirect to resource on successful file upload" do
      ResourceApi.stub(:update_resource?){1}
      put :update ,resource: FactoryGirl.attributes_for(:resource , :valid_file) , content_partner_id: 1 , id: 1
      expect(flash[:notice]).to eq I18n.t :successfuly_updated_resource
      response.should redirect_to controller: 'resources', action: 'show', id: 1
    end

    it "should re-render edit template on failed url" do
      ResourceApi.stub(:update_resource?){1}
      put :update ,resource: FactoryGirl.attributes_for(:resource , :invalid_url) , content_partner_id: 1  , id: 1
      #expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:edit)
    end

    it "should redirect to resource no file update" do
      ResourceApi.stub(:update_resource?){1}
      put :update ,resource: FactoryGirl.attributes_for(:resource , :update_no_file_update) , content_partner_id: 1  , id: 1
      expect(flash[:notice]).to eq I18n.t :successfuly_updated_resource
      response.should redirect_to controller: 'resources', action: 'show', id: 1
    end

    it "should redirect to resource with file update" do
      ResourceApi.stub(:update_resource?){1}
      put :update ,resource: FactoryGirl.attributes_for(:resource , :update_file_update) , content_partner_id: 1  , id: 1
      expect(flash[:notice]).to eq I18n.t :successfuly_updated_resource
      response.should redirect_to controller: 'resources', action: 'show', id: 1
    end

    it "should re-render edit template on failed save" do
      ResourceApi.stub(:update_resource?){1}
      put :update , resource: FactoryGirl.attributes_for(:resource , :invalid) , content_partner_id: 1 , id: 1
      #expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:edit)
    end
    
    it "should re-render edit template on failed update to scheduler or storage layer" do
      ResourceApi.stub(:update_resource?){nil}
      put :update , resource: FactoryGirl.attributes_for(:resource , :valid_url) , content_partner_id: 1 , id: 1
      expect(flash[:notice]).to eq I18n.t :error_in_connection
      expect(response.body).to render_template(:edit)
    end
  end
end