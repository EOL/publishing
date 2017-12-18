class Resource < ActiveRecord::Base
  belongs_to :partner, inverse_of: :resources

  has_many :nodes, inverse_of: :resource
  has_many :scientific_names, inverse_of: :resource
  has_many :import_logs, inverse_of: :resource
  has_many :media, inverse_of: :resource

  before_destroy :remove_content

  class << self
    def native
      Rails.cache.fetch("resources/native") do
        where(name: "Dynamic Working Hierarchy").first_or_create do |r|
          r.name = "Dynamic Working Hierarchy"
          r.partner = Partner.native
          r.description = "A synthesis of the hierarchies from EOL's trusted "\
            "partners, to be used for browsing eol.org"
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to read the IUCN status
    def iucn
      Rails.cache.fetch("resources/iucn") do
        Resource.where(name: "IUCN Structured Data").first_or_create do |r|
          r.name = "IUCN Structured Data"
          r.partner = Partner.native
          r.description = "TBD"
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to find the "best" Extinction Status: TODO: update the name when
    # we actually have the darn resource.
    def extinction_status
      Rails.cache.fetch("resources/extinction_status") do
        Resource.where(name: "Extinction Status").first_or_create do |r|
          r.name = "Extinction Status"
          r.partner = Partner.native
          r.description = "TBD"
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to find the "best" Extinction Status:
    def paleo_db
      Rails.cache.fetch("resources/paleo_db") do
        Resource.where(name: "The Paleobiology Database").first_or_create do |r|
          r.name = "The Paleobiology Database"
          r.partner = Partner.native
          r.description = "TBD"
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end
  end

  def create_log
    ImportLog.create(resource_id: id, status: "currently running")
  end

  def remove_content
    # Node ancestors
    nuke(NodeAncestor)
    # Node identifiers
    nuke(Identifier)
    # content_sections
    [Medium, Article, Link].each do |klass|
      pages = klass.where(resource_id: id).pluck(:page_id)
      field = "#{klass.name.pluralize.downcase}_count"
      Page.where(id: pages).update_all("#{field} = #{field} - 1")
      klass.where(resource_id: id).select("id").find_in_batches do |group|
        ContentSection.where(["content_type = ? and content_id IN (?)", klass.name, group.map(&:id)]).delete_all
        if klass == Medium
          # TODO: really, we should make note of these pages and "fix" their icons, now (unless the page itself is being
          # deleted):
          PageIcon.where(["medium_id IN (?)", group]).delete_all
        end
      end
    end
    # javascripts
    nuke(Javascript)
    # locations
    nuke(Location)
    # Bibliographic Citations
    nuke(BibliographicCitation)
    # references, referents
    nuke(Reference)
    nuke(Referent)
    # TODO: Update all these counts on affected pages:
      # t.integer  "page_contents_count",    limit: 4,   default: 0,     null: false
      # t.integer  "media_count",            limit: 4,   default: 0,     null: false
      # t.integer  "articles_count",         limit: 4,   default: 0,     null: false
      # t.integer  "links_count",            limit: 4,   default: 0,     null: false
      # t.integer  "maps_count",             limit: 4,   default: 0,     null: false
      # t.integer  "data_count",             limit: 4,   default: 0,     null: false
      # t.integer  "vernaculars_count",      limit: 4,   default: 0,     null: false
      # t.integer  "scientific_names_count", limit: 4,   default: 0,     null: false
      # t.integer  "referents_count",        limit: 4,   default: 0,     null: false
      # t.integer  "species_count",          limit: 4,   default: 0,     null: false

    # Media, image_info
    nuke(ImageInfo)
    nuke(ImportLog)
    nuke(Medium)
    # Articles
    nuke(Article)
    # Links
    nuke(Link)
    # occurrence_maps
    nuke(OccurrenceMap)
    # Scientific Names
    nuke(ScientificName)
    # Vernaculars
    nuke(Vernacular)
    # Attributions
    nuke(Attribution)
    # Traits:
    TraitBank::Admin.remove_for_resource(self)
    # Update page node counts
    # Get list of affected pages
    pages = Node.where(resource_id: id).pluck(:page_id)
    Page.where(id: pages).update_all("nodes_count = nodes_count - 1")
    nuke(Node)
    # Delete pages that no longer have nodes
    pages.in_groups_of(10_000, false) do |group|
      have = Node.where(page_id: group).pluck(:page_id)
      bad_pages = group - have
      # TODO: PagesReferent
      [PageIcon, ScientificName, SearchSuggestion, Vernacular, CollectedPage, Collecting, OccurrenceMap,
       PageContent].each do |klass|
        klass.where(page_id: bad_pages).delete_all
      end
      Page.where(id: bad_pages).delete_all
    end
  end

  def nuke(klass)
    klass.where(resource_id: id).delete_all
  end

  # TODO: BAAAAD smell here. Abstract the code for this, call it from Publishing, include it here.

  def import_traits(since)
    log = Publishing::PubLog.new(self)
    repo = Publishing::Repository.new(resource: self, log: log, since: since)
    log.log('Importing Traits ONLY...')
    begin
      Publishing::PubTraits.import(self, log, repo)
      log.log('NOTE: traits have been loaded, but richness has not been recalculated.', cat: :infos)
      log.complete
    rescue => e
      log.fail(e)
    end
    Rails.cache.clear
  end

  def import_media(since)
    log = Publishing::PubLog.new(self)
    repo = Publishing::Repository.new(resource: self, log: log, since: since)
    log.log('Importing Media ONLY...')
    begin
      Publishing::PubMedia.import(self, log, repo)
      log.log('NOTE: Media have been loaded, but richness has not been recalculated, page icons aren''t updated, and '\
        'media counts may be off.', cat: :infos)
      log.complete
    rescue => e
      log.fail(e)
    end
    Rails.cache.clear
  end
end
