class TraitBank::Denormalizer
  attr_reader :fixed

  class << self
    def update_attributes(options = {})
      denormalizer = new(options)
      denormalizer.update_attributes
    end

    def update_attributes_by_page_id(ids, options = {})
      denormalizer = new(options)
      denormalizer.update_attributes_by_page_id(ids)
    end
  end

  def initialize(options = {})
    @limit = options[:limit] || 1280
    @skip = options[:skip] || 0
    @fixed = 0
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

  def update_attributes_by_page_id(ids)
    ActiveRecord::Base.connection.reconnect!
    ids.in_groups_of(@limit, false) do |group_of_ids|
      update_data = build_update_data(group_of_ids)
      do_batch_update(update_data)
    end
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
      SET p.canonical = datum.canonical, p.rank = datum.rank
      RETURN count(*) AS count
    ), update_data: batch_data).first[:count]
    @fixed += updated_count
  end

  def build_update_data(ids)
    ::Page.references(native_node: :rank).includes(native_node: :rank)
      .where('pages.id': ids).map do |p| 
        { 
          page_id: p.id, 
          canonical: p.native_node&.canonical_form || '',
          rank: p.rank&.treat_as&.[](2..) || '' # treat_as value is prefixed with r_, so get the substring starting at 2
        }
    end
  end

  def get_page_ids
    page_q = PageNode.all.limit(@limit)
    page_q = page_q.skip(@skip) if @skip.positive?
    @skip += @limit
    page_q.pluck(:id)
  end

  # TODO: handle this better.
  def log(what)
    ts = "[#{Time.now.strftime('%H:%M:%S.%3N')}]"
    puts "** #{ts} #{what}"
    Rails.logger.info("#{ts} IMPORTER: #{what}")
  end
end
