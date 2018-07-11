class Vernacular < ActiveRecord::Base
  belongs_to :language
  belongs_to :node, inverse_of: :vernaculars
  belongs_to :resource, inverse_of: :vernaculars
  # DENORMALIZED:
  belongs_to :page, inverse_of: :vernaculars

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
      low_bound = batch.dup
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
  end

  def <=>(other)
    string <=> other.string
  end

end
