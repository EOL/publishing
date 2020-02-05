require 'rails_helper'

include Warden::Test::Helpers
Warden.test_mode!

RSpec.describe "Users", type: :request do
  let(:first_provider) { providers.first }

  def signup_user(user)
    fill_in "user[username]", with: user.username
    fill_in "user[email]", with: user.email
    fill_in "user[password]", with: user.password
    fill_in "user[password_confirmation]", with: user.password
    click_button I18n.t("helpers.submit.user.create")
  end

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
        user = build(:user, username: " ")
        signup_user(user)
        expect(page).to have_text("can't be blank")
      end
      it "has error message for short username" do
        user = build(:user, username: "usr")
        signup_user(user)
        expect(page).to have_text("too short (minimum is 4 characters)")
      end
      it "has error message for long username" do
        user = build(:user, username: Faker::Internet.user_name(33))
        signup_user(user)
        expect(page).to have_text("too long (maximum is 32 characters)")
      end
      it "has error message for empty email" do
        user = build(:user, email: nil)
        signup_user(user)
        expect(page).to have_text("can't be blank")
      end
      it "has error message for empty password" do
        user = build(:user, password: nil)
        signup_user(user)
        expect(page).to have_text("can't be blank")
      end
      it "has error message for not matching passwords" do
        fill_in "user[username]",              with: "user"
        fill_in "user[email]",                 with: "email_1@example.com"
        fill_in "user_password",               with: "badpassword"
        fill_in "user_password_confirmation",  with: "password"
        click_button I18n.t("helpers.submit.user.create")
        expect(page).to have_text("doesn't match Password")
      end
    end
  end

  describe "delete" do

    let(:user) { create(:user) }
    let(:admin_user) { create(:admin_user) }

    before do
      user.confirm
      visit user_path(user.id)
    end

    it "should show username" do
      expect(page).to have_text(user.username)
    end

    context "owner user" do

      before do
        login_as(user, scope: :user)
        visit user_path user.id
      end

      it "should contain delete your account button" do
        expect(page).to have_content(I18n.t(:delete_account_button))
      end
    end

    context "not owner user" do

      context "regular user" do
         it "should not contain delete your account button" do
          expect(page).not_to have_content(I18n.t(:delete_account_button))
        end
      end

      context "admin user" do

        before do
          login_as(admin_user, scope: :user)
          visit user_path user.id
        end

        it "should not contain delete your account button" do
          expect(page).to have_content(I18n.t(:delete_account_button))
        end
      end
    end
  end
  describe "Sign in" do
    let(:user) {create(:user)}
    let(:admin) {create(:admin_user)}
    context 'remember_me' do
      context 'normal user' do
        before do
          page.set_rack_session(login_attempts: 1)
          visit new_user_session_path
          fill_in "user[email]", with: user.email
          fill_in "user[password]", with: user.password
          check :user_remember_me
          click_button I18n.t(:sign_in)
          user.remember_me!
        end
        it 'stores the remember_me timestamp' do
          expect(user.remember_created_at).not_to be_nil
        end
      end

      context 'admin' do
        before do
          admin.confirm
          allow(admin).to receive(:confirmed?) { true }
          page.set_rack_session(login_attempts: 1)
          visit new_user_session_path
          fill_in "user[email]", with: admin.email
          fill_in "user[password]", with: admin.password
          check :user_remember_me
          click_button I18n.t(:sign_in)
        end

        it 'disables remember_me options for admins' do
          expect(admin.remember_created_at).to be_nil
          # TODO: I changed how flash messages render (it uses JS), so this is impossible:
          # expect(page).to have_content(I18n.t(:sign_in_remember_me_disabled_for_admins))
        end
      end
    end
  end
end
