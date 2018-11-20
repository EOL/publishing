class AddUserFields < ActiveRecord::Migration
  def change
    add_column :users, :v2_id, :integer
    add_column :users, :language_id, :integer
    add_column :users, :disable_email_notifications, :boolean

    # The following are to NOTE: for the script that will port users from v2 to v3...

    # User.where(active: true, hidden: false)
    #
    # role = 10
    # role = 100 if user.admin?
    # curator_level = user.curator_level_id
    # curator_level = 0 unless user.curator_approved
    #
    # {
    #   v2_id: user.id,
    #   email: user.email,
    #   language_id: user.language_id,
    #   encrypted_password: ???,
    #   username: user.username,
    #   name: user.given_name + " " + user.family_name,
    #   active: user.true,
    #   api_key: user.api_key,
    #   tag_line: user.tag_line,
    #   bio: user.bio + " Credentials: " + user.credentials + " Scope: " + user.curator_scope,
    #   uid: user.identity_url,
    #   role: role,
    #   curator_level: curator_level,
    #   disable_email_notifications: user.disable_email_notifications
    # }

  end
end
