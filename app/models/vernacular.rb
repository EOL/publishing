class Vernacular < ActiveRecord::Base
  belongs_to :language
  belongs_to :node, inverse_of: :vernaculars
  belongs_to :resource, inverse_of: :vernaculars
  # DENORMALIZED:
  belongs_to :page, inverse_of: :vernaculars
  belongs_to :user, inverse_of: :vernaculars

  scope :preferred, -> { where(is_preferred: true) }
  scope :nonpreferred, -> { where(is_preferred: false) }
  scope :current_language, -> { where(language_id: Language.current.id) }

  enum trust: [ :unreviewed, :trusted, :untrusted ]

  counter_culture :page

  class << self
    # YOU WERE HERE ... They need to re-harvest this resource.
    def pefer_best_english_names
      prefer_our_english_vernaculars
      prefer_names_per_page_id(language_id: Language.english.id)
    end

    def prefer_our_english_vernaculars
      vern_resource = Resource.find_by_abbr('English_Vernacul')
      english = Language.english.id
      vern_resource_verns = Vernacular.where(resource_id: vern_resource.id, language_id: english)
      have_pages = vern_resource_verns.pluck(:page_id)
      Vernacular.where(page_id: have_pages, is_preferred: true)
                .where(['resource_id != ?', vern_resource.id])
                .update_all(is_preferred: false)
      prefer_names_per_page_id(resource_id: vern_resource.id, language_id: english)
    end

    def prefer_names_per_page_id(clause = nil)
      batch = 10_000
      low_bound = 0
      max = Page.maximum(:id)
      iter_max = (max / batch) + 1
      iterations = 0
      puts "Iterating at most #{iter_max} times..."
      loop do
        limit = low_bound + batch
        pages = {}
        verns = Vernacular.where(['page_id >= ? AND page_id < ?', low_bound, limit]) ; 1
        verns = verns.where(clause) if clause
        verns.where(is_preferred: true).pluck(:page_id).each { |id| pages[id] = true }
        verns.find_each do |vern|
          next if pages.key?(vern.page_id)
          vern.update_attribute(:is_preferred, true)
          pages[vern.page_id] = true
        end
        low_bound = limit
        iterations += 1
        puts "... that was iteration #{iterations}/#{iter_max}"
        break if limit >= max || iterations > iter_max # Just making SURE we break...
      end
      puts "DONE."
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
            source: "https://eol.org/users/#{user_id}", resource_id: 1, user_id: user_id)
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

end
