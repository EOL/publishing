class AddUserFields < ActiveRecord::Migration
  def change
    add_column :users, :v2_id, :integer
    add_column :users, :language_id, :integer
    add_column :users, :disable_email_notifications, :boolean

    # The following are to NOTE: for the script that will port users from v2 to v3...
    if (false)
      users = {}
      User.where(active: true, hidden: false).find_each do |user|
        role = 10
        role = 100 if user.admin?
        curator_level = user.curator_level_id
        curator_level = 0 unless user.curator_approved

        parts = [user.bio]
        parts << "Credentials: " + user.credentials unless user.credentials.blank?
        parts << "Scope: " + user.curator_scope unless user.curator_scope.blank?
        bio = parts.compact.join(' ')

        parts = [user.given_name, user.family_name]
        name = parts.compact.join(' ')

        user_hash = {
          v2_ids: [user.id],
          email: user.email,
          language_id: user.language_id,
          username: user.username,
          name: name,
          active: true,
          api_key: user.api_key,
          tag_line: user.tag_line,
          bio: bio,
          uid: user.identity_url,
          role: role || 0,
          curator_level: curator_level || 0,
          disable_email_notifications: user.disable_email_notifications
        }

        # NOTE that this REMOVES earlier versions. Only the last user with any given email is preserved:
        if users.has_key?(user.email)
          user_hash[:v2_ids] = users[user.email][:v2_ids] + user_hash[:v2_ids]
          user_hash[:api_key] = users[user.email][:api_key] if user_hash[:api_key].blank?
          user_hash[:tag_line] = users[user.email][:tag_line] if user_hash[:tag_line].blank?
          user_hash[:bio] = users[user.email][:bio] if user_hash[:bio].blank?
          user_hash[:role] = users[user.email][:role] if users[user.email][:role] > user_hash[:role]
          user_hash[:curator_level] = users[user.email][:curator_level] if
            users[user.email][:curator_level] > user_hash[:curator_level]
        end
        users[user.email] = user_hash
      end
      file = Rails.root.join('public', 'user_dump.csv')
      keys = users.values.first.keys
      CSV.open(file, 'wb', encoding: 'UTF-8') do |csv|
        csv << keys
        users.each do |email, user_hash|
          user_hash[:v2_ids] = user_hash[:v2_ids].join(';')
          csv << keys.map { |k| user_hash[k] }
        end
      end
    end
    # Part 2, the import:
    if (false)
      def import_users(users)
        keys = %i[v2_ids api_key tag_line bio uid role curator_level disable_email_notifications]
        User.import(users, on_duplicate_key_update: keys)
      end
      data = CSV.read(Rails.public_path.join('data', 'user_dump.csv'))
      keys = data.shift # We don't use the headers here...
      roles = User.roles.invert
      users = []
      data.each do |row|
        row[1] ||= row[9] # Can't have blank email, so copy the OAuth ID... :\
        row[10] = row[10] ? roles[row[10].to_i].to_sym : 0
        u_hash = User.new(Hash[keys.zip(row)])
        u_hash.password = (0...20).map { ('a'..'z').to_a[rand(26)] }.join
        u_hash.password_confirmation = u_hash.password
        users << u_hash
        if users.size >= 100
          import_users(users)
          users = []
        end
      end
      import_users(users)
    end
  end
end
