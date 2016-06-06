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
<<<<<<< HEAD
        allow(controller).to receive(:verify_recaptcha) { true }
=======
        allow(controller).to receive(:verify_recaptcha).and_return(true)
>>>>>>> c0872bf89219cce76344a0fbc01dd6969991e912
        post :create, user: user.attributes
      end
    end
    
    context 'unverified recaptcha' do
      it "renders new action" do
<<<<<<< HEAD
        allow(controller).to receive(:verify_recaptcha) { false }
        post :create, user: {username: "user", email: "email_1@example.org", 
                             password: "password", password_confirmation: "password"}
        expect(response).to render_template :new
        debugger
        expect(response.body).to include("reCAPTCHA verification failed, please try again.")
=======
        allow(controller).to receive(:verify_recaptcha).and_return(false)
        post :create, user: {display_name: "user", email: "email_1@example.org", 
                             password: "password", password_confirmation: "password"}
        expect(response).to render_template("new")
        expect(response.body).to include("verification failed, please try again")
>>>>>>> c0872bf89219cce76344a0fbc01dd6969991e912
      end
    end
  end
end
