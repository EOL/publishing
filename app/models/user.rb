class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:facebook, :twitter,
                                             :google_oauth2, :yahoo]

  has_many :open_authentications, dependent: :delete_all
  
  after_update :send_reset_password_confirmation, if: :reset_password_token_changed?
  
  validates :username, presence: true,
   length: { minimum: 4, maximum: 32 }
    
  # NOTE: this is a hook called by Devise
  def after_confirmation
    self.update_attributes(active: true)
  end
  
  def send_reset_password_confirmation
    Devise::Mailer.password_change(self).deliver_now 
  end
  
  def soft_delete
    update_attributes(deleted_at: Time.current, email: nil,
      encrypted_password: nil, active: false)
  end

  # TODO: switch this to a role (once we have roles)
  def is_admin?
    admin?
  end

  def can_delete_account? (user)
    self.is_admin? || self == user
  end
end
