class OpenAuthentication < ActiveRecord::Base
  belongs_to :user
  
  def self.user_exists?(auth)
    user_id = select(:user_id).where(provider: auth.provider, uid: auth.uid).first
    user = User.find_by_id(user_id) if user_id
  end
  def self.from_omniauth(auth)
    # user_id = select(:user_id).where(provider: auth.provider, uid: auth.uid).first
    # user = User.find_by_id(user_id) if user_id
    if user_id.nil?  
#       Go to form to get email
      user = User.new(email: auth.info.email, password: Devise.friendly_token[0,16],
                      display_name: auth.info.name)
      user.skip_confirmation! 
      user.save
      user.after_confirmation
      create(user_id: user.id, provider: auth.provider, uid: auth.uid)
      return user
    end
  end  
end
