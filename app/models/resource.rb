class Resource < ApplicationRecord
  searchkick text_start: ["name"], batch_size: 250

  belongs_to :partner, inverse_of: :resources
  belongs_to :dataset_license, class_name: 'License', optional: true

  has_many :nodes, inverse_of: :resource
  has_many :scientific_names, inverse_of: :resource
  has_many :import_logs, inverse_of: :resource
  has_many :media, inverse_of: :resource
  has_many :articles, inverse_of: :resource
  has_many :links, inverse_of: :resource
  has_many :vernaculars, inverse_of: :resource
  has_many :referents, inverse_of: :resource
  has_many :term_query_filters

  before_destroy :destroy_callback

  scope :browsable, -> { where(is_browsable: true) }
  scope :classification, -> { where(classification: true) }

  def dwh?
    id == Resource.native.id
  end

  class << self
    def native
      # Note this CLASS method will return the FIRST resource flagged as native! That's hugely important. As we add new
      # ones, we'll use the old until the flag is flipped back to false. That's intentional: you'll need to continue to
      # use the "old" native resource (via Resource.native) for mathing of the new one, and yet you STILL need to know
      # that the new one WILL be "native" (via resource_instance.native?); both logics are used in names_matcher, for
      # example.
      find_by_native(true)
    end

    # Resource.update_native_nodes(resource: Resource.find(SOME_NEW_RESOURCE_ID)) --> start change before switchover
    # Resource.update_native_nodes --> Default, does everything from scratch. Slow.
    # Resource.update_native_nodes(resume: true) --> If the former times out, resume from about the same place.
    # Resource.update_native_nodes(start_id: 12345) --> If you lost your place, you can specify the node_id to start
    # with like this.
    def update_native_nodes(options = {})
      resource = options.has_key?(:resource) ? options[:resource] : Resource.native
      start_id = if options[:resume]
        raise "Cannot resume AND specify a start_id" if options.has_key?(:start_id)
        read_last_updated_native_node
      else
        options.has_key?(:start_id) ? options[:start_id] : 1
      end
      count = read_updated_native_node_count
      Searchkick.disable_callbacks # We will call these manually, in batches. Too slow individually.
      Searchkick.timeout = 500
      # This may actually be too large? 128 was failing frequently. :|
      batch_size = options.has_key?(:batch_size) ? options[:batch_size] : 64
      Node.joins(:page).
        where(['nodes.resource_id = ? AND pages.native_node_id != nodes.id AND node.id >= ?', resource.id, start_id]).
        select('nodes.id, nodes.page_id').
        find_in_batches(batch_size: 10_000) do |batch|
          record_last_updated_native_node(batch.first.id)
          batch_count = update_native_node_batch(batch, resource, batch_size)
          record_updated_native_node_count(count += batch_count)
        end
      resource.log('#update_native_nodes Done.')
      record_last_updated_native_node(1)
      record_updated_native_node_count(0)
      Searchkick.enable_callbacks
    end

    def read_last_updated_native_node
      File.read(Rails.public_path.join('last_updated_native_node.txt')).to_i
    end

    def record_last_updated_native_node(node_id)
      File.open(Rails.public_path.join('last_updated_native_node.txt'), 'w') { |file| file.write(node_id) }
    end

    def read_updated_native_node_count
      File.read(Rails.public_path.join('updated_native_node_count.txt')).to_i
    end

    def record_updated_native_node_count(count)
      File.open(Rails.public_path.join('updated_native_node_count.txt'), 'w') { |file| file.write(count) }
    end

    def update_native_node_batch(batch, resource, batch_size)
      count = 0
      node_map = {}
      batch.each { |node| node_map[node.page_id] = node.id }
      page_group = []
      resource.log("#{batch.size} nodes id > #{batch.first.id}")
      STDOUT.flush
      # NOTE: native_node_id is NOT indexed, so this is not speedy:
      Page.where(id: batch.map(&:page_id)).includes(:native_node).find_each do |page|
        next if page.native_node&.resource_id == resource.id
        count += 1
        page_group << page.id
        page.update_attribute :native_node_id, node_map[page.id]
        resource.log("Updated #{count}. Last: #{node_map[page.id]}") if (count % 1000).zero?
      end
      begin
        page_group.in_groups_of(batch_size, false) do |group|
          Searchkick::BulkReindexJob.perform_now(class_name: 'Page', record_ids: group)
        end
      rescue Faraday::TimeoutError => e
        batch_size /= 2
        raise e if batch_size <= 2
        retry
      end
      count
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

    # Other conservation status providers
    def cosewic
      Rails.cache.fetch('resources/cosewic') do
        Resource.find_by_abbr("COSEWIC")
      end
    end

    def cites
      Rails.cache.fetch('resources/cites') do
        Resource.find_by_abbr("cites_taxa_tar_g")
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

    # Required for GBIF link on data search page. Does NOT create the resource if it doesn't exist.
    def gbif
      Rails.cache.fetch('resources/gbif') do
        Resource.find_by(abbr: 'gbif_classificat')
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

    def for_traits(traits)
      resources = self.where(id: traits.map { |t| t[:resource_id] }.compact.uniq)
      # A little magic to index an array as a hash:
      Hash[ *resources.map { |r| [ r.id, r ] }.flatten ]
    end
  end

  # You would only call this manually, there should be no references to this method in code.
  def publish
    Publishing::Fast.by_resource(self)
  end

  def running
    import_logs.last.running
  end

  def unlock
    import_logs.running.update_all(failed_at: Time.now)
  end

  def path
    @path ||= abbr.gsub(/\s+/, '_')
  end

  def create_log
    new_log = ImportLog.create(resource_id: id, status: "currently running")
    import_logs << new_log
    new_log
  end

  def destroy_callback
    remove_all_content
    import_logs.destroy_all
  end

  def remove_non_trait_content
    [NodeAncestor, Identifier].each { |klass| nuke(klass) }
    [Medium, Article, Link].each { |klass| nuke_content_section(klass) }
    [Javascript, Location, BibliographicCitation, Reference, Referent].each { |klass| nuke(klass) }
    # TODO: Update these counts on affected pages:
      # t.integer  "maps_count",             limit: 4,   default: 0,     null: false
      # t.integer  "data_count",             limit: 4,   default: 0,     null: false
      # t.integer  "vernaculars_count",      limit: 4,   default: 0,     null: false
      # t.integer  "scientific_names_count", limit: 4,   default: 0,     null: false
      # t.integer  "referents_count",        limit: 4,   default: 0,     null: false
      # t.integer  "species_count",          limit: 4,   default: 0,     null: false
    [ImageInfo, Medium, Article, Link, OccurrenceMap, ScientificName, Vernacular, Attribution].each do |klass|
      nuke(klass)
    end
    update_page_node_counts
    nuke(Node)
    # You should run something like #fix_native_nodes (q.v.), but it's slow, and not terribly important if you are just
    # about to re-load the resource, so it's the responsibility of the caller to do it if desired.
    TraitBank::Admin.remove_non_trait_content_for_resource(self)
  end

  def remove_trait_content
    count = TraitBank::Queries.count_supplier_nodes_by_resource_nocache(id)
    if count.zero?
      log("No graph nodes, skipping.")
    else
      log("Removing #{count} graph nodes")
      TraitBank::Admin.remove_by_resource(self, log_handle)
    end
  end

  def remove_all_content
    remove_non_trait_content
    remove_trait_content
  end

  def log_handle
    @log ||= Publishing::PubLog.new(self, use_existing_log: true)
  end

  def log(message)
    log_handle.log(message, cat: :infos)
  end

  def log_update(message)
    log_handle.log_update(message)
  end

  def nuke(klass)
    total_count = klass.where(resource_id: id).count
    log("++ NUKE: #{klass} (#{total_count})")
    count = if total_count < 250_000
      log("++ Calling delete_all on #{total_count} instances...")
      STDOUT.flush
      klass.where(resource_id: id).delete_all
    else
      log("++ Batch removal of #{total_count} instances...")
      log("Starting (this log message should be replaced shortly)")
      batch_size = 10_000
      times = 0
      expected_times = (total_count / batch_size.to_f).ceil
      max_times = expected_times * 2
      begin
        log_update("Batch #{times} (expect #{expected_times} batches, maximum #{max_times})...")
        STDOUT.flush
        klass.connection.execute("DELETE FROM `#{klass.table_name}` WHERE resource_id = #{id} LIMIT #{batch_size}")
        times += 1
        sleep(0.5) # Being (moderately) nice.
      end while klass.where(resource_id: id).count.positive? && times < max_times
      raise "Failed to delete all of the #{klass} instances! Tried #{times}x#{batch_size} times." if
        klass.where(resource_id: id).count.positive?
      total_count
    end
    log("Removed #{count} #{klass.name.humanize.pluralize}")
    STDOUT.flush
  rescue => e # reports as Mysql2::Error but that doesn't catch it. :S
    log("There was an error, retrying: #{e.message}")
    STDOUT.flush
    sleep(2)
    ActiveRecord::Base.connection.reconnect!
    retry rescue "UNABLE TO REMOVE #{klass.name.humanize.pluralize}: timed out"
  end

  def nuke_content_section(klass)
    total_count = klass.where(resource_id: id).count
    log("++ NUKE: #{klass} (#{total_count})")
    all_pages = {}
    klass.where(resource_id: id).select('id, page_id').find_each do |instance|
      all_pages[instance.page_id] ||= []
      all_pages[instance.page_id] << instance.id
    end
    field = "#{klass.name.pluralize.downcase}_count"
    all_pages.each do |page_id, group|
      ContentSection.where(["content_type = ? and content_id IN (?)", klass.name, group]).delete_all
      # TODO: really, we should make note of these pages and "fix" their icons, now (unless the page itself is being
      # deleted):
      PageIcon.where(["medium_id IN (?)", group]).delete_all if klass == Medium
      contents = PageContent.where(page_id: page_id, content_type: klass, content_id: group)
      content_count = contents.count
      contents.delete_all
      Page.where(id: page_id).update_all("#{field} = #{field} - #{group.size}, page_contents_count = page_contents_count - #{content_count}")
    end
  end

  def update_page_node_counts
    log("Updating page node counts...")
    Node.where(resource_id: id).pluck(:page_id).in_groups_of(5000, false) do |group|
      Page.where(id: group).update_all("nodes_count = nodes_count - 1")
    end
  end

  def clear_import_logs
    import_logs.each do |log|
      log_name = log.created_at.strftime('%Y-%m-%d %H:%M')
      last_event = log.import_events.last
      if last_event
        old_events = log.import_events.where(['created_at < ?', last_event.created_at - 60])
        unless old_events.count.zero?
          old_events.destroy_all
          log("Removed events older than the last minute for log on #{log_name}.")
        end
      else
        log.destroy
        log("Removed empty log from #{log_name}")
      end
    end
  end

  def fix_native_nodes
    node_ids = Node.where(resource_id: id).pluck(:id)
    node_ids.in_groups_of(1000, false) do |group|
      Page.fix_missing_native_nodes(Page.where(native_node_id: group))
    end
  end

  # This is kinda cool... and MUCH faster than fix_counter_culture_counts
  def fix_missing_page_contents(options = {})
    log("Fixing missing page contents")
    delete = options.key?(:delete) ? options[:delete] : false
    [Medium, Article, Link].each { |klass| fix_missing_page_contents_by_type(klass, options.merge(delete: delete)) }
  end

  # TODO: this should be extracted and generalized so that a resource_id is an option (thus allowing ALL contents to be
  # fixed).
  def fix_missing_page_contents_by_type(klass, options = {})
    log("Fixing #{klass}")
    delete = options.key?(:delete) ? options[:delete] : false
    by_count = {}
    count_contents_per_page(klass, delete, options).each { |page_id, count| by_count[count] ||= [] ; by_count[count] << page_id }
    fix_page_content_counts_on_pages(klass, by_count, delete) unless by_count.empty?
  end

  # Homegrown #find_in_batches because of custom content_id ranges...
  def count_contents_per_page(klass, delete, options)
    page_counts = {}
    contents = PageContent.where(content_type: klass.name, resource_id: id)
    contents = contents.where(options[:clause]) if options[:clause]
    first_content_id = klass.where(resource_id: id).first&.id
    last_content_id = klass.where(resource_id: id).last&.id
    if first_content_id.nil? || last_content_id.nil?
      puts "Failed to find any content to count, aborting"
      log("#count_contents_per_page found zero content, skipping.")
      return {}
    end
    delta = last_content_id - first_content_id
    batch_num = 0
    batch_start = first_content_id
    batch_end = batch_start + 2000
    batch_end = last_content_id if batch_end > last_content_id
    batches = (delta / 2000.0).ceil
    loop do
      batch_contents = contents.where(["content_id >= ? AND content_id <= ?", batch_start, batch_end])
      batch_contents.pluck(:page_id).each { |pid| page_counts[pid] ||= 0 ; page_counts[pid] += 1 }
      batch_contents.delete_all if delete
      puts "Batch #{batch_num += 1}/#{batches} (#{batch_start}-#{batch_end} --> #{page_counts.keys.size})"
      log("Batch #{batch_num}/#{batches} (#{batch_end}/#{last_content_id}, #{page_counts.keys.size} done)") if
        (batch_num % 50).zero?
      break if batch_end >= last_content_id
      batch_start = batch_end
      batch_end = batch_start + 2000
      batch_end = last_content_id if batch_end > last_content_id
    end
    page_counts
  end

  def fix_page_content_counts_on_pages(klass, by_count, delete)
    by_count.each do |count, pages|
      pages.in_groups_of(5_000, false) do |group|
        pages = Page.where(id: group)
        klass_field = "#{klass.table_name}_count"
        update =
          if delete
            "page_contents_count = IF(page_contents_count > #{count}, (page_contents_count - #{count}),0), "\
              "#{klass_field} = IF(#{klass_field} > #{count}, (#{klass_field} - #{count}),0)"
          else
            "page_contents_count = page_contents_count + #{count}, #{klass_field} = #{klass_field} + #{count}"
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
    nodes.pluck(:page_id).in_groups_of(1280, false) do |page_ids|
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

  def republish
    Delayed::Job.enqueue(RepublishJob.new(id))
  end

  # Meant to be called manually:
  def republish_traits
    Publishing::Fast.traits_by_resource(self)
  end

  # Note this does NOT include metadata!
  def trait_count
    TraitBank::Admin.query(%{MATCH (trait:Trait)-[:supplier]->(:Resource { resource_id: #{id} }) RETURN COUNT(trait)})['data'].first.first
  end

  def file_dir
    Rails.public_path.join('data', abbr)
  end

  def ensure_file_dir
    dir = file_dir
    FileUtils.mkdir(dir) unless File.exist?(dir)
    dir
  end

  def remove_traits_files
    FileUtils.remove_dir(file_dir) if File.exist?(file_dir)
  end

  def cached_nodes_count
    Rails.cache.fetch("resources/#{id}/nodes_count") do
      nodes.count
    end
  end

  def cached_media_count
    Rails.cache.fetch("resources/#{id}/media_count") do
      media.count
    end
  end

  def self.autocomplete(query, options = {})
    search(query, options.reverse_merge({
      fields: ['name'],
      match: :text_start,
      limit: 10,
      load: false,
      misspellings: false,
      highlight: { tag: "<mark>", encoder: "html" }
    }))
  end
end
