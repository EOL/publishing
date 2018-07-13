class User
  class Port
    def build_csv
      raise "NONO, this was meant to be run on the old code. It's here for posterity."
      old_users = User.where(active: true, agreed_with_terms: true, hidden: false) ; 1
      # old_users.count => 50228
      keys_required = [:id, :email, :given_name, :family_name, :identity_url, :username, :language_id, :created_at, :notes, :curator_approved, :curator_verdict_by_id, :curator_verdict_at, :credentials, :curator_scope, :logo_cache_url, :logo_file_name, :logo_content_type, :tag_line, :bio, :curator_level_id, :admin, :disable_email_notifications]
      users = {}
      old_users.select(keys_required).find_each do |user|
        # NOTE: this ends up keeping only the LAST entry found.
        if users.key?(user.email)
          user.id = Array(users[user.email]) << user.id
        end
        users[user.email] = keys_required.map do |k|
          v = user.send(k) ; v.is_a?(String) ? v.tr("\n", ' ') : v
        end
      end ; 1
      # users.values.size => 49221
      CSV.open(Rails.root.join('public', 'users.csv'), 'wb') { |csv| users.values.each { |l| csv << l } } ; 1
    end

    def from_csv(file)

    end
  end
end
