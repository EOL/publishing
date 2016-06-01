class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
         
  validates :username, presence: true, uniqueness: true,
                       length: {minimum: 4, maximum: 32}

  def after_confirmation
    self.update_attributes(active: true)
  end
  
  def soft_delete
    update_attributes(deleted_at: Time.current, email: nil, encrypted_password: nil, active: false)
  end
  
  def is_admin?
    self.admin.blank? ? false : self.admin 
  end
  
  def can_delete_account? (user)
    self.is_admin? || self == user ? true : false 
  end
end
