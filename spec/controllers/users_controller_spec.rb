require 'rails_helper'

RSpec.describe User::UsersController, type: :controller do
  
  render_views
  let(:user) { create(:user) }
  
  describe '#delete_user' do
    before do
      user.confirm
      sign_in user
      @total_number_before_delete = User.count
      post :delete_user , id: user.id
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
