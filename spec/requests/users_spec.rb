require 'rails_helper'

RSpec.describe "Users", type: :request do
  describe "Sign_up" do
    before do
      visit new_user_registration_path
    end
    context "Sign_up form" do
      it "has username field" do
        expect(page).to have_selector("label", text: "Username")
        expect(page).to have_field(:user_username)
      end
      it "has email field" do
        expect(page).to have_selector("label", text: "Email")
        expect(page).to have_field(:user_email)
      end
      it "has password field" do
        expect(page).to have_selector("label", text: "Password")
        expect(page).to have_field(:user_password)
      end
      it "password confirmation field" do
        expect(page).to have_selector("label", text: "Password confirmation")
        expect(page).to have_field(:user_password_confirmation)
      end
      it "has recaptcha field" do
        expect(page).to have_selector("label", text: "Recaptcha")
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
end
