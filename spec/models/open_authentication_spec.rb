require 'rails_helper'
require 'omniauth_helper'
RSpec.describe OpenAuthentication, type: :model do
  # pending "add some examples to (or delete) #{__FILE__}"
  describe '.oauth_user_exists' do
    options = {email: "user1@example.org", name: "user1", provider: "twitter", uid: "1234567"}
 
    context 'when user exists' do
      auth = set_omniauth_hash(options)
      let(:user) { FactoryGirl.create(:user, email: auth.email, display_name: auth.name) }
      before { FactoryGirl.create(:open_authentication, user_id: user.id, provider: auth.provider, uid: auth.uid) }
      
      it 'finds and returns user' do
        auth.merge(user_id: user.id)
        oauth_user = OpenAuthentication.oauth_user_exists?(auth)
        expect(oauth_user).to be_valid
      end
    end
    
    context 'when user doesnot exist' do
      it "returns nil user" do
        auth = set_omniauth_hash(options)
        auth.merge(user_id: nil)
        oauth_user = OpenAuthentication.oauth_user_exists?(auth)
        expect(oauth_user).to be_nil
      end
    end
  end
  
end
