require 'rails_helper'
include Warden::Test::Helpers
Warden.test_mode!

RSpec.describe "Users", type: :request do
  describe "Sign_up" do
    before do
      visit new_user_registration_path
    end
    context "Sign_up form" do
      it "has username field" do
        expect(page).to have_selector("label", text: I18n.t(:username))
        expect(page).to have_field(:user_username)
      end
      it "has email field" do
        expect(page).to have_selector("label", text: I18n.t(:email))
        expect(page).to have_field(:user_email)
      end
      it "has password field" do
        expect(page).to have_selector("label", text: I18n.t(:password))
        expect(page).to have_field(:user_password)
      end
      it "password confirmation field" do
        expect(page).to have_selector("label", text: I18n.t(:password_confirmation))
        expect(page).to have_field(:user_password_confirmation)
      end
      it "has recaptcha field" do
        expect(page).to have_selector("label", text: I18n.t(:recaptcha))
      end
    end 
    context "Invalid signup" do
      before do
        visit new_user_registration_path
      end
      it "has error message for empty username" do
        fill_in :user_username,              with: " "
        fill_in :user_email,                 with: "email_1@example.com "
        fill_in :user_password,              with: "password"
        fill_in :user_password_confirmation, with: "password"
        click_button "Sign up"
        expect(page).to have_text("Username can't be blank")
      end
      it "has error message for short username" do
        fill_in :user_username,              with: "usr"
        fill_in :user_email,                 with: "email_1@example.com "
        fill_in :user_password,              with: "password"
        fill_in :user_password_confirmation, with: "password"
        click_button "Sign up"
        expect(page).to have_text("Username is too short (minimum is 4 characters)")
      end
      it "has error message for long username" do
        fill_in :user_username,              with: Faker::Internet.user_name(33)
        fill_in :user_email,                 with: "email_1@example.com "
        fill_in :user_password,              with: "password"
        fill_in :user_password_confirmation, with: "password"
        click_button "Sign up"
        expect(page).to have_text("Username is too long (maximum is 32 characters)")
      end
      it "has error message for empty email" do
        fill_in :user_username,              with: "user_1"
        fill_in :user_email,                 with: " "
        fill_in :user_password,              with: "password"
        fill_in :user_password_confirmation, with: "password"
        click_button "Sign up"
        expect(page).to have_text("Email can't be blank")
      end
      it "has error message for empty password" do
        fill_in :user_username,              with: "user_1"
        fill_in :user_email,                 with: "email_1@example.com"
        fill_in :user_password,              with: " "
        fill_in :user_password_confirmation, with: "password"
        click_button "Sign up"
        expect(page).to have_text("Password can't be blank")
      end
      it "has error message for not matching passwords" do
        fill_in :user_username,              with: "user_1"
        fill_in :user_email,                 with: "email_1@example.com"
        fill_in :user_password,              with: " "
        fill_in :user_password_confirmation, with: "password"
        click_button "Sign up"
        expect(page).to have_text("Password confirmation doesn't match Password")
      end
    end
  end

  describe "Sign in" do
    let(:user) {create(:user)}
    # let(:admin) {create(:user, admin: true)}
    context 'remember_me' do
      context 'normal user' do 
        before do
          page.set_rack_session(login_attempts: 1) 
          visit new_user_session_path
          fill_in  I18n.t(:email), with: user.email
          fill_in I18n.t(:password), with: user.password
          check :user_remember_me
          click_button I18n.t(:sign_in)
          user.remember_me!
        end
        it 'stores the remember_me timestamp' do
          expect(user.remember_created_at).not_to be_nil
        end
      end

      # context 'admin' do
        # before do
          # page.set_rack_session(login_attempts: 1) 
          # visit new_user_session_path
          # fill_in "Email", with: admin.email
          # fill_in "Password", with: admin.password
          # check "Remember me"
          # click_button "Sign in"
        # end
# 
        # it 'disables remember_me options for admins' do
          # expect(admin.remember_created_at).to be_nil 
          # expect(page).to have_selector("p[id='flash_alert']",
           # text: I18n.t(:sign_in_remember_me_disabled_for_admins, scope: 'devise.sessions'))
        # end
      # end
    end
  end
end

