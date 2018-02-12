class MediaContentCreator
  def self.by_resource(resource, log)
    self.new(resource, log).by_resource
  end

  def initialize(resource, log)
    @resource = resource
    @log = log
  end

  def reset_batch
    @contents = []
    @naked_pages = {}
    @ancestry = {}
    @content_count_by_page = {}
  end

  def by_resource
    @log.log('MediaContentCreator#by_resource', cat: :starts)
    [Medium, Article].each do |k|
      @klass = k
      @field = "#{@klass.name.underscore.downcase}_id".to_sym
      @klass.where(resource: @resource.id).where('page_id IS NOT NULL').find_in_batches do |batch|
        reset_batch
        learn_ancestry(batch)
        batch.each do |content|
          add_content(content.page_id, content)
          add_ancestry_content(content)
        end
        push_pages_down
        import_contents
        update_naked_pages if k == Medium
        fix_counter_culture_counts
      end
    end
  end

  def learn_ancestry(batch)
    Page.includes(native_node: [:unordered_ancestors, { node_ancestors: :ancestor }])
        .where(id: batch.map(&:page_id))
        .each do |page|
          @naked_pages[page.id] = page if page.send(@field).nil?
          @ancestry[page.id] = page.ancestry_ids
        end
  end

  def add_content(page_id, content)
    @content_count_by_page[page_id] ||= -1
    @content_count_by_page[page_id] += 1
    @contents << { page_id: page_id, source_page_id: page_id, position: @content_count_by_page[page_id],
                   content_type: @klass.name, content_id: content.id, resource_id: @resource.id }
    if @naked_pages.key?(page_id)
      @naked_pages[page_id].assign_attributes(@field: content.id)
    end
  end

  def add_ancestry_content(content)
    if @ancestry.key?(content.page_id)
      @ancestry[content.page_id].each do |ancestor_id|
        add_content(ancestor_id, content) unless ancestor_id == content.page_id
      end
    end
  end

  def push_pages_down
    @log.log("Pushing contents down...")
    push_pages = {}
    @content_count_by_page.each do |page_id, count|
      push_pages[count] ||= []
      push_pages[count] << page_id
    end
    push_pages.each do |count, pages|
      PageContent.where(page_id: pages).update_all(['position = position + ?', count])
    end
  end

  def import_contents
    # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
    # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
    @log.log("import #{@contents.size} page contents...")
    PageContent.import(@contents, on_duplicate_key_ignore: true)
  end

  def update_naked_pages
    unless @naked_pages.empty?
      @log.log("updating #{@naked_pages.values.size} pages with icons...")
      Page.import!(@naked_pages.values, on_duplicate_key_update: [@field])
    end
  end

  def fix_counter_culture_counts
    @log.log("Fixing counter-culture counts...")
    PageContent.where(content_type: @klass.name, content_id: @contents.map { |c| c[:content_id] }).counter_culture_fix_counts
  end
end
