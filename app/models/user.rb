class User < ActiveRecord::Base

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, authentication_keys: [:username_or_email]
  attr_accessor :username_or_email
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  


  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if username_or_email = conditions.delete(:username_or_email)
      where(conditions.to_h).where(["lower(username) = :value OR lower(email) = :value", { :value => username_or_email.downcase }]).first
    elsif conditions.has_key?(:username) || conditions.has_key?(:email)
      where(conditions.to_h).first
    end
  end
end
