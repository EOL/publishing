class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # NOTE: Devise validates a few fields, including password.
  validates :username, presence: true, uniqueness: true,
                       length: {minimum: 4, maximum: 32}

  # NOTE: this is a hook called by Devise
  def after_confirmation
    self.update_attributes(active: true)
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
