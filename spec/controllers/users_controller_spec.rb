require 'rails_helper'

RSpec.describe User::RegistrationsController, type: :controller do
  
  render_views
  let(:user) { create(:user) }
  
  before :each do
    request.env["devise.mapping"] = Devise.mappings[:user]  
  end
  
  describe '#destroy' do
    
    before do
      user.confirm
      sign_in user
      @total_number_before_delete = User.count
      post :destroy, method: :delete
    end
    
    it "should not decrement total number of users" do
      expect(User.count).to eq(@total_number_before_delete)
    end
    
    it "should sign out the user session" do
      expect(subject.current_user).to be_nil
    end
    
    it "should redirect to sign in page" do
      expect(response).to redirect_to(controller.after_sign_out_path_for(user))
    end
    
    it "should have flash message" do
      expect(flash[:notice]).not_to be_nil
    end
    
  end

end
