class OpenAuthentication < ApplicationRecord
  belongs_to :user

  def self.oauth_user_exists?(auth)
    oauth_user = where(provider: auth.provider, uid: auth.uid).last
    User.find_by_id(oauth_user.user_id) if oauth_user
  end
end
