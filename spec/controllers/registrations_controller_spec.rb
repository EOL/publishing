require 'rails_helper'

RSpec.describe User::RegistrationsController, type: :controller do
  render_views
  describe 'check_captcha' do
    before do
      request.env["devise.mapping"] = Devise.mappings[:user]
    end
    let(:user) { create(:user) }

    context 'verified recaptcha' do
      it "renders create action" do
        allow(controller).to receive(:verify_recaptcha) { true }
        post :create, user: user.attributes
      end
    end

    context 'unverified recaptcha' do
      it "renders new action" do
       allow(controller).to receive(:verify_recaptcha) { false }
        post :create, user: { username: "user",
          email: "email_1@example.org", password: "password",
          password_confirmation: "password" }
        expect(response).to render_template("new")
        expect(response.body).to include(I18n.t(:recaptcha_error))
      end
    end
  end
  
  
  describe "Adding user" do
    
    before do
      request.env["devise.mapping"] = Devise.mappings[:user]
    end
    
    context "valid parameters" do
      it "redirects to root path" do
        post :create, user: { username: "new_user", email: "new_user_email@example.org",
                              password: "password123", password_confirmation: "password123" }
        expect(response).to redirect_to(root_path)
      end
      
      it "shows a successful registeration message" do
        post :create, user: { username: "new_user", email: "new_user_email@example.org",
                              password: "password123", password_confirmation: "password123" }
        expect(flash[:notice]).to be_present
      end
    end
    
    context "invalid parameters" do

      it "rejects dupliacte emails" do
        create(:user, email: "new_user_email@example.org")
        post :create, user: { username: "new_user", email: "new_user_email@example.org",
                              password: "password123", password_confirmation: "password123" }
        expect(response.body).to include("Email has already been taken")
      end
    end
  end
end
