require 'rails_helper'

RSpec.describe User::RegistrationsController, type: :controller do
  render_views
  describe 'check_captcha' do
    before do
       request.env["devise.mapping"] = Devise.mappings[:user]
    end
    let(:user) {create(:user)}
    
    context 'verified recaptcha' do
      it "renders create action" do
        allow(controller).to receive(:verify_recaptcha).and_return(true)
        post :create, user: user.attributes
      end
    end
    
    context 'unverified recaptcha' do
      it "renders new action" do
        allow(controller).to receive(:verify_recaptcha).and_return(false)
        post :create, user: {username: "user", email: "email_1@example.org", 
                             password: "password", password_confirmation: "password"}
        expect(response).to render_template("new")
        expect(response.body).to include("verification failed, please try again")
      end
    end
  end
end
