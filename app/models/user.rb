class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
         
  validates :username, presence: true, uniqueness: true,
                       length: {minimum: 4, maximum: 32}

  def after_confirmation
    self.update_attribute(:active, true)
  end
  
end
