class Resource < ActiveRecord::Base
  belongs_to :partner, inverse_of: :resources

  has_many :nodes, inverse_of: :resource
  has_many :scientific_names, inverse_of: :resource
  has_many :import_logs, inverse_of: :resource
  has_many :media, inverse_of: :resource
  has_many :articles, inverse_of: :resource
  has_many :links, inverse_of: :resource
  has_many :vernaculars, inverse_of: :resource
  has_many :referents, inverse_of: :resource

  before_destroy :remove_content

  def dwh?
    id == Resource.native.id
  end

  class << self
    def native
      Rails.cache.fetch('resources/native') do
        Resource.where(abbr: 'DWH').first_or_create do |r|
          r.name = 'EOL Dynamic Hierarchy'
          r.partner = Partner.native
          r.description = 'TBD'
          r.abbr = 'DWH'
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # Required to read the IUCN status
    def iucn
      Rails.cache.fetch('resources/iucn') do
        Resource.where(abbr: 'IUCN-SD').first_or_create do |r|
          r.name = 'IUCN Structured Data'
          r.partner = Partner.native
          r.description = 'TBD'
          r.abbr = 'IUCN-SD'
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
      Rails.cache.fetch('resources/paleo_db') do
        Resource.where(abbr: 'pbdb').first_or_create do |r|
          r.name = 'The Paleobiology Database'
          r.partner = Partner.native
          r.description = 'TBD'
          r.abbr = 'pbdb'
          r.is_browsable = true
          r.has_duplicate_nodes = false
        end
      end
    end

    # NOTE: This order is deterministic and conflated with HarvDB's app/models/publisher.rb ... if you change one, you
    # must change the other.
    def trait_headers
      %i[eol_pk page_id scientific_name resource_pk predicate sex lifestage statistical_method source
         object_page_id target_scientific_name value_uri literal measurement units]
    end

    # NOTE: This order is deterministic and conflated with HarvDB's app/models/publisher.rb ... if you change one, you
    # must change the other.
    def meta_headers
      %i[eol_pk trait_eol_pk predicate literal measurement value_uri units sex lifestage
        statistical_method source]
    end
  end

  def path
    @path ||= abbr.gsub(/\s+/, '_')
  end

  def create_log
    ImportLog.create(resource_id: id, status: "currently running")
  end

  def remove_content_with_rescue
    log = []
    begin
      remove_content(log)
    rescue => e
      i_log = import_logs&.last || create_log
      log.each { |l| i_log.log(l) }
      i_log.fail(e)
    end
  end

  def remove_content(log = nil)
    log ||= []
    # Node ancestors
    log << nuke(NodeAncestor)
    # Node identifiers
    log << nuke(Identifier)
    # content_sections
    [Medium, Article, Link].each do |klass|
      all_pages = klass.where(resource_id: id).pluck(:page_id)
      field = "#{klass.name.pluralize.downcase}_count"
      all_pages.in_groups_of(2000, false) do |pages|
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
    end
    # javascripts
    log << nuke(Javascript)
    # locations
    log << nuke(Location)
    # Bibliographic Citations
    log << nuke(BibliographicCitation)
    # references, referents
    log << nuke(Reference)
    log << nuke(Referent)
    fix_missing_page_contents(delete: true)
    # TODO: Update these counts on affected pages:
      # t.integer  "maps_count",             limit: 4,   default: 0,     null: false
      # t.integer  "data_count",             limit: 4,   default: 0,     null: false
      # t.integer  "vernaculars_count",      limit: 4,   default: 0,     null: false
      # t.integer  "scientific_names_count", limit: 4,   default: 0,     null: false
      # t.integer  "referents_count",        limit: 4,   default: 0,     null: false
      # t.integer  "species_count",          limit: 4,   default: 0,     null: false

    # Media, image_info
    log << nuke(ImageInfo)
    log << nuke(ImportLog)
    log << nuke(Medium)
    # Articles
    log << nuke(Article)
    # Links
    log << nuke(Link)
    # occurrence_maps
    log << nuke(OccurrenceMap)
    # Scientific Names
    log << nuke(ScientificName)
    # Vernaculars
    log << nuke(Vernacular)
    # Attributions
    log << nuke(Attribution)
    # Traits:
    count = TraitBank.count_by_resource_no_cache(id)
    if count.zero?
      log << "[#{Time.now.strftime('%H:%M:%S.%3N')}] No traits, skipping."
    else
      log << "[#{Time.now.strftime('%H:%M:%S.%3N')}] Removing #{count} traits"
      TraitBank::Admin.remove_for_resource(self)
    end
    # Update page node counts
    # Get list of affected pages
    log << "[#{Time.now.strftime('%H:%M:%S.%3N')}] Updating page node counts..."
    pages = Node.where(resource_id: id).pluck(:page_id)
    pages.in_groups_of(5000, false) do |group|
      Page.where(id: group).update_all("nodes_count = nodes_count - 1")
    end
    log << nuke(Node)
    # You should run something like #fix_native_nodes (q.v.), but it's slow, so it's the responsibility of the caller to
    # do it if desired.
    log
  end

  def nuke(klass)
    count = klass.where(resource_id: id).delete_all
    "[#{Time.now.strftime('%H:%M:%S.%3N')}] Removed #{count} #{klass.name.humanize.pluralize}"
  rescue # reports as Mysql2::Error but that doesn't catch it. :S
    sleep(2)
    ActiveRecord::Base.connection.reconnect!
    retry rescue "[#{Time.now.strftime('%H:%M:%S.%3N')}] UNABLE TO REMOVE #{klass.name.humanize.pluralize}: timed out"
  end

  def fix_native_nodes
    node_ids = Node.where(resource_id: id).pluck(:id)
    node_ids.in_groups_of(1000, false) do |group|
      Page.fix_missing_native_nodes(Page.where(native_node_id: group))
    end
  end

  # This is kinda cool... and faster than fix_counter_culture_counts
  def fix_missing_page_contents(options = {})
    delete = options.key?(:delete) ? options[:delete] : false
    [Medium, Article, Link].each { |type| fix_missing_page_contents_by_type(type, options.merge(delete: delete)) }
  end

  # TODO: this should be extracted and generalized so that a resource_id is options (thus allowing ALL contents to be
  # fixed). TODO: I think the pluck at the beginning will need to be MANUALLY segmented, as it takes too long
  # (285749.5ms on last go).
  def fix_missing_page_contents_by_type(type, options = {})
    delete = options.key?(:delete) ? options[:delete] : false
    page_counts = {}
    type_table = type.table_name
    first_content_id = type.where(resource_id: id).first&.id
    last_content_id = type.where(resource_id: id).last&.id
    contents = PageContent.where(content_type: type.name, resource_id: id).
                           where(["content_id >= ? AND content_id <= ?", first_content_id, last_content_id])
    contents = contents.where(options[:clause]) if options[:clause]
    if delete
      contents.joins(
        %Q{LEFT JOIN #{type_table} ON (page_contents.content_id = #{type_table}.id)}
      ).where("#{type_table}.id IS NULL")
    else
      PageContent
    end
    # .where('page_contents.id > 31617148').pluck(:page_id)
    contents.pluck(:page_id).each { |pid| page_counts[pid] ||= 0 ; page_counts[pid] += 1 }
    by_count = {}
    page_counts.each { |pid, count| by_count[count] ||= [] ; by_count[count] << pid }
    contents.delete_all if delete
    by_count.each do |count, pages|
      pages.in_groups_of(5_000, false) do |group|
        pages = Page.where(id: group)
        type_field = "#{type.table_name}_count"
        update =
          if delete
            "page_contents_count = IF(page_contents_count > #{count}, (page_contents_count - #{count}),0), "\
              "#{type_field} = IF(#{type_field} > #{count}, (#{type_field} - #{count}),0)"
          else
            "page_contents_count = page_contents_count + #{count}, #{type_field} = #{type_field} + #{count}"
          end
        pages.update_all(update)
      end
    end
  end

  def fix_missing_base_urls
    %w[base_url unmodified_url].each do |field|
      all = Medium.where(resource_id: id).where("#{field} LIKE 'data%'").select("id, #{field}")
      all.find_in_batches do |batch|
        Medium.where(id: batch.map(&:id)).update_all("#{field} = CONCAT('https://repo.eol.org/', #{field})")
      end
    end
  end

  # The name of this method is based on the SYMPTOM. The underlying cause is that native nodes are *wrong* because of
  # previous publishes of this resource leaving "zombie" pages with old node ids, and new publishes recognizing that the
  # page already HAS a native_node_id and thus leaving it alone.
  def fix_no_names
    nodes.pluck(:page_id).in_groups_of(5000, false) do |page_ids|
      # This loop is slow. I don't mind terribly much, this is just a fix. It took about 12 seconds on a resource with
      # only 700 nodes. You have been warned!
      Page.where(id: page_ids).
           joins('LEFT JOIN nodes ON nodes.id = pages.native_node_id').
           where('nodes.id IS NULL').
           each do |page|
             nn_id = Node.where(resource_id: id, page_id: page.id).pluck(:id)&.first
             next if nn_id.nil?
             page.update_attribute(:native_node_id, nn_id)
           end
    end
  end

  # Goes and asks the Harvesting site for information on how to move the nodes between pages...
  def move_nodes
    Node::Mover.by_resource(self)
  end

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

  def slurp_traits
    TraitBank::Slurp.load_csvs(self)
  end

  def traits_file
    Rails.public_path.join("traits_#{id}.csv")
  end

  def meta_traits_file
    Rails.public_path.join("meta_traits_#{id}.csv")
  end

  def remove_traits_files
    File.unlink(traits_file) if File.exist?(traits_file)
    File.unlink(meta_traits_file) if File.exist?(meta_traits_file)
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
