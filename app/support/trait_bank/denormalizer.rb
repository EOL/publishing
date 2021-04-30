class TraitBank::Denormalizer
  attr_reader :fixed

  class << self
    def update_attributes(options = {})
      denormalizer = new(options)
      denormalizer.update_attributes
    end

    def update_attributes_by_page_id(resource, ids, options = {})
      denormalizer = new(options)
      denormalizer.update_attributes_by_page_id(resource, ids)
    end
  end

  def initialize(options = {})
    @limit = options[:limit] || 1280
    @skip = options[:skip] || 0
    @fixed = 0
    @vernacular_count = 0
  end

  def update_attributes
    @pages_count = PageNode.count # 4,332,394 as of this writing...
    log "Looks like there are #{@pages_count} pages to check (#{((@pages_count * 1.0) / @limit).ceil} batches)..."
    loop do
      page_ids = get_page_ids
      break if page_ids.empty?
      log "Handing #{@skip}/#{@pages_count}..."
      fix_page_ids(page_ids)
    end
    @fixed
  end

  def update_attributes_by_page_id(resource, ids)
    ActiveRecord::Base.connection.reconnect!
    ids.in_groups_of(@limit, false) do |group_of_ids|
      update_data = build_update_data(group_of_ids)
      do_batch_update(update_data)
      update_vernaculars(resource, group_of_ids)
    end
    log("Fixed #{@fixed} pages")
    log("Created #{@vernacular_count} vernaculars")
  end

  def fix_page_ids(page_ids)
    update_data = build_update_data(page_ids.compact)
    do_batch_update(update_data)
  end

  def do_batch_update(batch_data)
    updated_count = ActiveGraph::Base.query(%Q(
      WITH $update_data AS update_data
      UNWIND update_data AS datum
      MATCH (p:Page)
      WHERE p.page_id = datum.page_id
      SET p.canonical = datum.canonical, p.rank = datum.rank, p.landmark = datum.landmark
      RETURN count(*) AS count
    ), update_data: batch_data).first[:count]
    @fixed += updated_count
  end

  def build_update_data(ids)
    ::Page.includes(native_node: :rank)
      .where('pages.id': ids).map do |p| 
        landmark = p.native_node&.no_landmark? ? nil : p.native_node&.landmark

        { 
          page_id: p.id, 
          canonical: p.native_node&.canonical_form,
          rank: p.rank&.treat_as&.[](2..), # treat_as value is prefixed with r_, so get the substring starting at 2
          landmark: landmark
        }
    end
  end

  def get_page_ids
    page_q = PageNode.all.limit(@limit)
    page_q = page_q.skip(@skip) if @skip.positive?
    @skip += @limit
    page_q.pluck(:id)
  end

  def update_vernaculars(resource, page_ids)
    resource.vernaculars.includes(language: :code).where(page_id: page_ids).find_in_batches do |batch|
      data = batch.map do |v|
        {
          page_id: v.page_id,
          is_preferred_name: v.is_preferred_by_resource,
          language_code: v.language.code,
          string: v.string
        }
      end

      do_vernacular_update(resource, data)
    end
  end

  def do_vernacular_update(resource, data)
    query = <<~CYPHER
      MATCH (resource:Resource)
      WHERE resource.resource_id = $resource_id
      WITH resource, $data AS data
      UNWIND data AS datum
      MATCH (page:Page)
      WHERE page.page_id = datum.page_id
      CREATE (v:Vernnacular)
      SET v.string = datum.string, v.is_preferred_name = datum.is_preferred_name, v.language_code = datum.language_code
      CREATE (v)-[:supplier]->(resource), (page)-[:vernacular]->(v)
      RETURN count(*) AS count
    CYPHER

    count = ActiveGraph::Base.query(query, resource_id: resource.id, data: data).first.count
    @vernacular_count += count
  end


  # TODO: handle this better.
  def log(what)
    ts = "[#{Time.now.strftime('%H:%M:%S.%3N')}]"
    puts "** #{ts} #{what}"
    Rails.logger.info("#{ts} IMPORTER: #{what}")
  end
end
