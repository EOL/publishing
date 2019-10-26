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
    def prefer_best_vernaculars
      batch = 1000
      low_bound = 1
      max = Page.maximum(:id)
      iter_max = (max / batch) + 1
      iterations = 0
      puts "Iterating at most #{iter_max} times..."
      completed_pages_by_language = {}
      total_count = 0
      loop do
        limit = low_bound + batch
        verns = Vernacular.where(['page_id >= ? AND page_id < ?', low_bound, limit])
        verns.where(is_preferred: true, language_id: Language.english.id).each do |vern|
          completed_pages_by_language[vern.language_id] ||= {}
          completed_pages_by_language[vern.language_id][vern.id] = true
        end
        total_count += prefer_names_per_page_id(verns, completed_pages_by_language)
        low_bound = limit
        iterations += 1
        puts "... that was iteration #{iterations}/#{iter_max} (#{total_count} added.)" if
          (iterations % 300).zero?
        break if limit >= max || iterations > iter_max # Just making SURE we break...
      end
      puts "DONE."
    end

    def prefer_names_per_page_id(verns, completed_pages_by_language)
      @scores ||= ResourcePreference.hash_for_class('Vernacular')
      groups = verns.group_by(&:page_id)
      preferred_ids = []
      groups.keys.each do |page_id|
        groups[page_id].group_by(&:language_id).each do |language_id, verns_by_language|
          # No thanks, I've already GOT one...
          next if completed_pages_by_language.key?(language_id) &&
                  completed_pages_by_language[language_id].key?(page_id)
          sorted = verns_by_language.compact.sort { |a,b| @scores[a.resource_id] <=> @scores[b.resource_id] }
          preferred_ids << sorted.first.id
          completed_pages_by_language[language_id] ||= {}
          completed_pages_by_language[language_id][page_id] = true
        end
      end
      Vernacular.where(id: preferred_ids).update_all(is_preferred: true)
      preferred_ids.count
    end

    def import_user_added
      @file = DataFile.assume_path('user_added_names', 'user_added_names.tab')
      @file.dbg("Starting!")
      rows = @file.to_array_of_hashes
      @users = get_users # NOTE: this is keyed to STRINGS, not integers. That's fine when reading TSV.
      rows.each do |row|
        # [:namestring, :iso_lang, :user_id, :taxon_id]
        begin
          language = get_language(row[:iso_lang])
          page = pick_page(row)
          next if page.nil?
          node = page.native_node || page.nodes.first # Rarely happens, but... occassionaly, at least on beta.
          user_id = pick_user(row[:user_eol_id], row[:user_name])
          unless exists?(string: row[:namestring], language_id: language.id, node_id: node.id, page_id: page.id,
                         trust: 1, source: "https://eol.org/users/#{user_id}", resource_id: Resource.native.id,
                         user_id: user_id)
            create(string: row[:namestring], language_id: language.id, node_id: node.id, page_id: page.id, trust: :trusted,
              source: "https://eol.org/users/#{user_id}", resource_id: Resource.native.id, user_id: user_id)
          end
        rescue => e
          # @file.dbg("Missing a record; skipping #{row[:namestring]}: #{e.message} ")
          puts("ERROR ON #{row[:namestring]}: #{e.message} ")
          raise e
        end
      end
      @file.dbg("Done!")
    end

    def import_user_preferred
      @file = DataFile.assume_path('user_preferred_comnames.txt')
      @file.dbg("Starting!")
      rows = @file.to_array_of_hashes
      @users = get_users # NOTE: this is keyed to STRINGS, not integers. That's fine when reading TSV.
      @names = get_names_from_file(rows)
      rows.each_with_index do |row,row_num|
        # [:namestring, :iso_lang, :user_id, :taxon_id]
        begin
          language = get_language(row[:iso_lang])
          page = pick_page(row)
          next if page.nil?
          user_id = pick_user(row[:user_eol_id], row[:user_name])
          unless @names.key?(row[:namestring])
            @file.dbg("SKIPPING `#{row[:namestring]}` (line #{row_num+2}) because I can't find that name in the DB.")
            next
          end
          unless @names[row[:namestring]].key?(language.id)
            @file.dbg("SKIPPING `#{row[:namestring]}` (line #{row_num+2}) because I can't find that name in the DB with a language of #{row[:iso_lang]}.")
            next
          end
          unless @names[row[:namestring]][language.id].key?(page.id)
            @file.dbg("SKIPPING `#{row[:namestring]}` (line #{row_num+2}) because I can't find that name in the DB with a page ID of #{page.id}.")
            next
          end
          if row[:preferred] == "0" || row[:preferred].downcase == "false" || row[:preferred].downcase == "no"
            # We don't have a way of recording that a user DOESN'T prefer a name, like we did in V2. ...Just ... make it
            # happen:
            @names[row[:namestring]][language.id][page.id].update_attribute(:is_preferred, false)
          else
            VernacularPreference.user_preferred(user_id, @names[row[:namestring]][language.id][page.id])
          end
        rescue => e
          @file.dbg("ERROR while processing #{row[:namestring]} (line #{row_num + 2}): #{e.message} ")
          raise e
        end
      end
      @file.dbg("Done!")
    end

    def get_language(iso)
      iso = 'en' if iso.blank?
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

    # NOTE: you might be tempted to pass in rows here and pluck the v2 ids from it and search on that, but: that field
    # in the tables is not readily searchable (it's a ;-delimited array) and you will end up slowing things down.
    def get_users
      @users = {}
      # There are just over 90K users from V2, and it's easier to just load them all. :\ This only takes a few seconds:
      User.select('id, v2_ids').where('v2_ids IS NOT NULL').find_each do |user|
        user.v2_ids.split(';').each { |id| @users[id] = user.id }
      end
      @users
    end

    def pick_user(v2_id, name)
      @missing_users ||= {}
      if @users.key?(v2_id)
        @users[v2_id]
      elsif !@missing_users.key?(v2_id)
        @file.dbg("MISSING USER #{name} (#{v2_id}), going to fake it as Admin...")
        @missing_users[v2_id] = true
        1
      else
        1
      end
    end

    def pick_page(row)
      return Page.find(row[:taxon_id]) if Page.exists?(id: row[:taxon_id])
      # DON'T just do the find, it is MUCH slower than exists + find.
      return ScientificName.find_by_canonical_form("<i>#{row[:taxon_name]}</i>") if
        ScientificName.exists?(canonical_form: "<i>#{row[:taxon_name]}</i>")
      return ScientificName.find_by_canonical_form(row[:taxon_name]) if
        ScientificName.exists?(canonical_form: row[:taxon_name])
      @file.dbg("SKIPPING `#{row[:namestring]}` because I can't find a page matching #{row[:taxon_name]} (#{row[:taxon_id]})")
      nil
    end

    def get_names_from_file(rows)
      @names = {}
      name_strings = rows.map { |r| r[:namestring] }.sort.uniq # This will have 11K names
      Vernacular.where(string: name_strings).find_each do |name|
        next if name.nil? # Missing name
        unless @names[name.string] && @names[name.string][name.language_id] &&
               @names[name.string][name.language_id][name.page_id]
          @names[name.string] ||= {}
          @names[name.string][name.language_id] ||= {}
          @names[name.string][name.language_id][name.page_id] = name
        end
      end
      @names
    end
  end

  def <=>(other)
    string <=> other.string
  end

  # DON'T USE THIS METHOD (unless you know you MUST). Use VernacularPreference.user_preferred when possible.
  def prefer
    return nil unless page&.respond_to?(:vernaculars)
    page.vernaculars.where(language_id: language_id).where(['vernaculars.id != ?', id]).update_all(is_preferred: false)
    update_attribute(:is_preferred, true)
  end
end
