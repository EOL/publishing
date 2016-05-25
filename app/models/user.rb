class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:facebook, :twitter, :google_oauth2, :yahoo]
         
  validates :username, presence: true, uniqueness: true,
                       length: {minimum: 4, maximum: 32}

  def after_confirmation
    self.update_attribute(:active, true)
  end
  
  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first
    if user.nil?  
      auth.info.email = "#{auth.info.name}@#{auth.provider}.com" if auth.info.email.nil?
      user = new(email: auth.info.email, password: Devise.friendly_token[0,16],
                 username: auth.info.name, provider: auth.provider, uid: auth.uid)
      user.skip_confirmation! 
      user.save
      user.after_confirmation
      return user
    end
  end  
end