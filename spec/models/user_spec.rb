require 'rails_helper'

RSpec.describe User, type: :model do
  # pending "add some examples to (or delete) #{__FILE__}"
  describe 'UserFactoryGirl' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end
  end 
  
  describe 'Validation' do   
    it "has a username" do
       expect(FactoryGirl.build(:user, username: nil)).to_not be_valid
    end
   
    it "rejects duplicate username" do
      FactoryGirl.create(:user, username: 'user')
      expect(FactoryGirl.build(:user, username: 'user')).to_not be_valid
    end
    
    it "rejects too short username" do
      expect(FactoryGirl.build(:user, username: 'usr')).to_not be_valid
    end
  
    it "rejects too long username" do
      expect(FactoryGirl.build(:user, username: Faker::Internet.user_name(33))).to_not be_valid
    end
  
    it "has an email" do
      expect(FactoryGirl.build(:user, email: nil)).to_not be_valid
    end
    
    it "is invalid with duplicated email" do
      FactoryGirl.create(:user, email: 'user@example.com')
      expect(FactoryGirl.build(:user, email: 'user@example.com')).to_not be_valid
    end 
    
    it "rejects email in worng format" do
      wrong_emails = %w[user@foo,com user_at_foo.org example.user@foo.foo@bar_baz.com foo@bar+bar.com]
      wrong_emails.each do |email|
        expect(FactoryGirl.build(:user, email: email)).to_not be_valid
      end
    end 
  
    it "accepts email in correct format" do
      correct_emails = %w[user@foo.COM A_US-ER@f.b.org]
      correct_emails.each do |email|
        expect(FactoryGirl.build(:user, email: email)).to be_valid
      end
    end
    
    it "has a password" do
      expect(FactoryGirl.build(:user, password: nil)).to_not be_valid
    end
    it "rejects too short passwords" do
      expect(FactoryGirl.build(:user, password: 'pas')).to_not be_valid
    end
    
    it "rejects too long passwords " do
      expect(FactoryGirl.build(:user, password:  Faker::Internet.password(17))).to_not be_valid
    end
  end
  
  describe 'Confirmation' do
    before do
      @user = FactoryGirl.create(:user)
      @user.confirm
    end
    it "updates users's confirmed_at attribute" do
      expect(@user.confirmed_at).to_not be_nil
    end
    it "activates user after confirming account" do
      @user.after_confirmation
      expect(@user.active).to eq(true)
    end
  end
end
