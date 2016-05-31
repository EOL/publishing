class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:facebook, :twitter,
                                             :google_oauth2, :yahoo]
         
  
   # @email_regex = %r{\A(?:[_\+a-z0-9-]+)(\.[_\+a-z0-9-]+)*@([a-z0-9-]+)(\.[a-zA-Z0-9\-\.]+)*(\.[a-z]{2,4})/z}i
  validates :display_name, presence: true,length: {minimum: 4, maximum: 32}
  # validates :email, presence: true, format: @email_regex
  # validates_format_of :email, with: Devise::email_regexp
  has_many :open_authentications

  def after_confirmation
    self.update_attribute(:active, true)
  end
  
  # def self.from_omniauth(auth)
    # user = where(provider: auth.provider, uid: auth.uid).first
    # if user.nil?  
      # auth.info.email = "#{auth.info.name}@#{auth.provider}.com" if auth.info.email.nil?
      # user = new(email: auth.info.email, password: Devise.friendly_token[0,16],
                 # display_name: auth.info.name, provider: auth.provider, uid: auth.uid)
      # user.skip_confirmation! 
      # user.save
      # user.after_confirmation
      # return user
    # end
  # end  
end