class User < ActiveRecord::Base
  searchkick word_start: [:username, :name]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :lockable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:facebook, :twitter,
                                             :google_oauth2]

  has_many :open_authentications, dependent: :delete_all
  has_many :curations, inverse_of: :user
  has_many :data_curations, inverse_of: :user
  has_many :added_associations, class_name: "PageContent", foreign_key: "association_added_by_user_id"
  has_many :page_icons, inverse_of: :user

  has_and_belongs_to_many :partners
  has_and_belongs_to_many :collections

  scope :active, -> { where(["confirmed_at IS NOT NULL AND active = ?", true]) }

  # TODO: we want to pick the real sizes to use, here:
  has_attached_file :icon, styles: { medium: "130x130>" },
    default_url: "/images/:style/missing.png"

  validates :username, presence: true, length: { minimum: 4, maximum: 32 }
  validates :email, presence: true
  validates :password, presence: true, if: "encrypted_password.blank?"
  validates :password_confirmation, presence: true, if: "encrypted_password.blank?"
  # LATER: causes errors for now. :S
  # validates_attachment_content_type :icon, content_type: /\Aimage\/.*\z/

  USERNAME_MIN_LENGTH = 4
  USERNAME_MAX_LENGTH = 32

  def self.autocomplete(query, options = {})
    search(query, options.reverse_merge({
      fields: ["username", "name"],
      match: :word_start,
      limit: 10,
      load: false,
      misspellings: false
    }))
  end

  # NOTE: this is a hook called by Devise
  def after_confirmation
    activate
  end

  def activate
    skip_confirmation!
    self.active = true
    save
  end

  def soft_delete
    self.skip_reconfirmation!
    Devise.send_password_change_notification = false
    weird_password = SecureRandom.hex(8)
    self.update_attributes!(deleted_at: Time.current,
      email: dummy_email_for_delete, active: false,
      password: weird_password, password_confirmation: weird_password)
  end

  # def email_required?
    # false
  # end

  # TODO: switch this to a role (once we have roles)
  def is_admin?
    admin?
  end

  def grant_admin
    self.update_attribute(:admin, true)
  end

  def revoke_admin
    self.update_attribute(:admin, false)
  end

  def can_delete_account? (user)
    self.is_admin? || self == user
  end

  def can_edit_collection?(collection)
    self.collections.include?(collection)
  end

end

private
  def dummy_email_for_delete
    "dummy_#{self.id}@eol.org"
  end
