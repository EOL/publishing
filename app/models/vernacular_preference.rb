# Describes the ACT of a user having preferred a vernacular on a particular page.
class VernacularPreference < ActiveRecord::Base
  belongs_to :user
  belongs_to :vernacular
  belongs_to :language # Helps us lookup overrides and restores.
  belongs_to :page # Helps us lookup overrides.
  belongs_to :overridden_by, class_name: 'VernacularPreference'
  has_many :overrides, class_name: 'VernacularPreference', foreign_key: :overridden_by_id

# TO TEST:
# name = Vernacular.last
# ...when to that page, clicked on a different name to prefer it
# VernacularPreference.all
# ...checked that they were being created and that the old ones were being "overridden".
# VernacularPreference.restore_for_resource(468)
# ...checked that it was calling the right queries :\ I should have un-preferred the last name directly, ran that, then
# checked that it had been re-preferred. It would also be good to check that it didn't prefer OLD preferences.

  class << self
    # NOTE: we keep copies of some information from the original vernacular, so if that is removed, we'll still at least
    # know who prefered which name for which language from which resource... allowing us to recreate it if the resource is
    # reharvested.
    def user_preferred(user_id, name)
      user_id = user_id.id if user_id.is_a?(User)
      transaction do
        overridden_ids = where(language_id: name.language_id, page_id: name.page_id).pluck(:id)
        pref = create(user_id: user_id, vernacular_id: name.id, resource_id: name.resource_id,
          page_id: name.page_id, language_id: name.language_id, string: name.string)
        name.prefer # Yes, we "must" use this method, here, obviously.
        where(id: overridden_ids).update_all(overridden_by_id: pref.id)
      end
    end

    def restore_for_resource(resource_id, log = nil)
      where(resource_id: resource_id, overridden_by_id: nil).includes(:page).find_each do |pref|
        next if pref.page.nil? # The page no longer exsits, this is irrelevant.
        names = Vernacular.where(resource_id: resource_id, string: pref.string, language_id: pref.language_id)
        count = names.count
        if count.zero?
          log_or_puts("Missing matching name for VernacularPreference.find(#{pref.id}) (#{pref.string})", log)
          next
        elsif count > 1
          log_or_puts("MULTIPLE matching names for VernacularPreference.find(#{pref.id}) (#{pref.string}), "\
            "using first.", log)
        end
        name = names.first
        name.prefer # Yes, we "must" use this method, here, since we don't have a user.
      end
    end

    def log_or_puts(msg, log = nil)
      if log
        log.log(msg, cat: :warns)
      else
        puts "[#{Time.now.strftime('%F %T')}] #{msg}"
      end
    end
  end
end
