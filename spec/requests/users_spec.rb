require 'rails_helper'

RSpec.describe "Users", type: :request do
  describe "Sign_up" do
    before do
      visit new_user_registration_path
    end

    describe "Sign_up form" do
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
  end
end
