require 'rails_helper'

RSpec.describe User::SessionsController, type: :controller do
  render_views
  let(:user) {create(:user)}

  before(:each) do
    request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe '#new' do

    before do
      user.confirm
      get :new
    end

    it "returns a 200 ok status" do
      expect(response).to have_http_status(:ok)
    end

    it 'counts the login attempts per session' do
      expect(session[:login_attempts]).to eq(1)
    end

    it 'displays recaptcha tags for multiple failure sign ins' do
      get :new
      expect(session[:login_attempts]).not_to be_nil
      expect(session[:login_attempts] > 1).to be true
      expect(response.body).to have_selector "div[class='g-recaptcha']"
    end

    it 'does not show the sign in page if a user is already signed in' do
      sign_in user
      get :new
      expect(flash[:alert]).to eq I18n.t :already_authenticated, scope: 'devise.failure'
    end
  end
  
  describe '#create' do

    context 'successful sign in' do
      before do
        allow(request.env['warden']).to receive(:authenticate!) {user}
        allow(controller).to receive(:verify_recaptcha) { true }
        allow(controller).to receive(:session) { {login_attempts: 2} }
        allow(controller).to receive(:sign_in_params) { {email: user.email} }
        post :create
      end

      it 'redirects to root path' do
        expect(response).to redirect_to root_path
      end
      it 'gives a successful signin flash' do
        expect(flash[:notice]).to eq I18n.t :signed_in, scope: 'devise.sessions' 
      end
 

    end

    context 'failed sign in' do 

      context 'invalid recaptcha' do
        before do
          allow(request.env['warden']).to receive(:authenticate!) {user}
          allow(controller).to receive(:verify_recaptcha) { false }
          allow(controller).to receive(:session) { {login_attempts: 2} }
          allow(controller).to receive(:sign_in_params) { {email: user.email} }
          post :create 
        end

        it 'display an invalid recaptcha flash' do
          expect(flash[:alert]).to eq I18n.t :recaptcha_error, scope: 'devise.failure' 
        end
        
        it 'renders the new template' do
          expect(response).to render_template :new
        end
      end

      context "invalid user's params" do
        before do
          invalid_user_params = {email: "non_existing_user", password: "invalid"}
          allow(controller).to receive(:session) { {login_attempts: 1} }
          post :create, user: invalid_user_params
          allow(controller).to receive(:sign_in_params) { invalid_user_params }
        end

        it 'displays an invalid user flash' do
          expect(flash[:alert]).to eq I18n.t :invalid,
            authentication_keys: "Email" , scope: 'devise.failure'
        end

        it 'renders the new template' do
          expect(response).to render_template :new
        end
      end
    end
  end
end
