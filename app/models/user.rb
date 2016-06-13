class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:facebook, :twitter,
                                             :google_oauth2, :yahoo]

  has_many :open_authentications, dependent: :delete_all

  validates :username, presence: true,
   length: { minimum: 4, maximum: 32 }

  def after_confirmation
    self.update_attributes(active: true)
  end

end
