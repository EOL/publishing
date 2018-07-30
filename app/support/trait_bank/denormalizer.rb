class TraitBank::Denormalizer
  delegate :connection, to: TraitBank
  delegate :query, to: TraitBank
  delegate :count_pages, to: TraitBank
  attr_reader :fixed

  class << self
    def set_canonicals
      denormalizer = new()
      denormalizer.set_canonicals
    end
  end

  def initialize
    @limit = 10_000
    @skip = 0
    @fixed = 0
    @pages_count = count_pages # 4,332,394 as of this writing...
  end

  def set_canonicals
    log "Looks like there are #{@pages_count} pages to check (#{(@pages_count / @limit).ceil} batches)..."
    loop do
      results = get_pages
      break if results.nil?
      log "Handing #{@skip}/#{@pages_count}..."
      pages = map_page_ids_to_canonical(results.map(&:first))
      results.each do |page_id, canonical|
        fix_canonical(page_id, pages[page_id]) if pages[page_id] != canonical
      end
    end
    @fixed
  end

  def fix_canonical(id, name)
    name.gsub!('"', '""')
    query(%{MATCH (page:Page { page_id: #{id} }) SET page.canonical = "#{name}" })
    @fixed += 1
  end

  def map_page_ids_to_canonical(ids)
    Hash[*Page.joins([:native_node]).where(id: ids).pluck('pages.id, nodes.canonical_form').flatten]
  end

  def get_pages
    q = %{MATCH (page:Page) RETURN page.page_id, page.canonical LIMIT #{@limit}}
    q += " SKIP #{@skip}" if skip.positive?
    results = query(q)
    @skip += @limit
    return nil if results.nil? || !results.key?("data") || results["data"].empty?
    results["data"]
  end
end
