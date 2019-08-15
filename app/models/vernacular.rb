class Vernacular < ActiveRecord::Base
  belongs_to :language
  belongs_to :node, inverse_of: :vernaculars
  belongs_to :resource, inverse_of: :vernaculars
  # DENORMALIZED:
  belongs_to :page, inverse_of: :vernaculars
  belongs_to :user, inverse_of: :vernaculars

  has_many :vernacular_preferences, inverse_of: :vernacular # NOTE: do NOT destroy! We keep the record.

  scope :preferred, -> { where(is_preferred: true) }
  scope :nonpreferred, -> { where(is_preferred: false) }
  scope :current_language, -> { where(language_id: Language.current.id) }

  enum trust: [ :unreviewed, :trusted, :untrusted ]

  counter_culture :page

  class << self
    def prefer_names_per_page_id
      batch = 1000
      low_bound = 0
      max = Page.maximum(:id)
      iter_max = (max / batch) + 1
      iterations = 0
      puts "Iterating at most #{iter_max} times..."
      completed_pages = {}
      loop do
        limit = low_bound + batch
        verns = Vernacular.where(['page_id >= ? AND page_id < ?', low_bound, limit])
        verns.where(is_preferred: true).pluck(:page_id).each { |id| completed_pages[id] = true }
        prefer_best_vernaculars(verns, completed_pages)
        low_bound = limit
        iterations += 1
        puts "... that was iteration #{iterations}/#{iter_max} (#{completed_pages.count} added.)"
        break if limit >= max || iterations > iter_max # Just making SURE we break...
      end
      puts "DONE."
    end

    def prefer_best_vernaculars(verns, completed_pages)
      @scores ||= ResourcePreference.hash_for_class('Vernacular')
      groups = verns.group_by(&:page_id)
      preferred_ids = []
      groups.keys.each do |page_id|
        next if completed_pages.key?(vern.page_id) # No thanks, I've already GOT one...
        sorted = groups[page_id].compact.sort { |a,b| scores[a.resource_id] <=> scores[b.resource_id] }
        preferred_ids << sorted.first.id
        completed_pages[page_id] = true
      end
      Vernacular.where(id: preferred_ids).update_attribute(:is_preferred, true)
    end

    def import_user_added
      file = DataFile.assume_path('user_added_names', 'user_added_names.tab')
      file.dbg("Starting!")
      rows = file.to_array_of_hashes
      # Find pages in batches, including native_node
      # Find users in batches. Argh.
      @users = get_users # NOTE: this is keyed to STRINGS, not integers. That's fine when reading TSV.
      rows.each do |row|
        # [:namestring, :iso_lang, :user_id, :taxon_id]
        begin
          language = get_language(row[:iso_lang])
          page = Page.find(row[:taxon_id])
          node = page.native_node
          user_id = @users[row[:user_id]]
          # TODO: you need a migration.
          create(string: row[:namestring], language_id: language.id, node_id: node.id, page_id: page.id, trust: :trusted,
            source: "https://eol.org/users/#{user_id}", resource_id: Resource.native.id, user_id: user_id)
        rescue ActiveRecord::RecordNotFound => e
          file.dbg("Missing a record; skipping #{row[:namestring]}: #{e.message} ")
        end
      end
      file.dbg("Done!")
    end

    def get_language(iso)
      @languages ||= {}
      if @languages.key?(iso)
        @languages[iso]
      else
        @languages[iso] =
          if Language.exists?(code: iso)
            Language.find_by_code(iso)
          elsif Language.exists?(group: iso)
            Language.find_by_group(iso)
          else
            Language.create!(code: iso, group: iso, can_browse_site: false)
          end
      end
    end

    def get_users
      @users = {}
      # There are just over 90K users from V2, and it's easier to just load them all. :\ This only takes a few seconds:
      User.select('id, v2_ids').where('v2_ids IS NOT NULL').find_each do |user|
        user.v2_ids.split(';').each { |id| @users[id] = user.id }
      end
      @users
    end
  end

  def <=>(other)
    string <=> other.string
  end

  # DON'T USE THIS METHOD (unless you know you MUST). Use VernacularPreference.user_preferred when possible.
  def prefer
    page.vernaculars.where(language_id: language_id).where(['vernaculars.id != ?', id]).update_all(is_preferred: false)
    update_attribute(:is_preferred, true)
  end
end
