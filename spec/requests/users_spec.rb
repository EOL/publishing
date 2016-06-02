require 'rails_helper'
include Warden::Test::Helpers
Warden.test_mode!

RSpec.describe "Users", type: :request do
  describe "Sign in" do
    let(:user) {create(:user)}
    let(:admin) {create(:user, admin: true)}
    context 'remember_me' do
      context 'normal user' do 
        before do
          page.set_rack_session(login_attempts: 1) 
          visit new_user_session_path
          fill_in "Email", with: user.email
          fill_in "Password", with: user.password
          check "Remember me"
          click_button ""
          user.remember_me!
        end
        it 'stores the remember_me timestamp' do
          expect(user.remember_created_at).not_to be_nil
        end
      end

      context 'admin' do
        before do
          page.set_rack_session(login_attempts: 1) 
          visit new_user_session_path
          fill_in "Email", with: admin.email
          fill_in "Password", with: admin.password
          check "Remember me"
          click_button "Sign in"
        end

        it 'disables remember_me options for admins' do
          expect(admin.remember_created_at).to be_nil 
          expect(page).to have_selector("p[id='flash_alert']", text: I18n.t(:sign_in_remember_me_disabled_for_admins, scope: 'devise.sessions'))
        end
      end
    end
  end
end