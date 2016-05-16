class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:facebook]
         
  validates :username, presence: true, uniqueness: true,
                       length: {minimum: 4, maximum: 32}

  def after_confirmation
    self.update_attribute(:active, true)
  end
  
  def self.from_omniauth(auth)
    where(provider: "facebook", uid: "10154208169262427").first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0,16]
      user.username = auth.info.name
      user.skip_confirmation! 
      user.update_attribute(:active, true)
      debugger
    end
     debugger 
  end
  
  def self.new_with_session(params, session)
    debugger
    super.tap do |user|
      if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
      end
    end
  end 
  
end
