class MediaContentCreator
  def self.by_resource(resource, options = {})
    self.new(resource, options[:log], start: options[:id]).by_resource(options)
  end

  def initialize(resource, log = nil, options = {})
    @resource = resource
    @log = log || ImportLog.where(resource_id: @resource.id).last
    @options = options
  end

  def reset_batch
    @contents = []
    @naked_pages = {}
    @ancestry = {}
    @content_count_by_page = {}
  end

  def by_resource(options = {})
    clause = options[:clause] || 'page_id IS NOT NULL'
    @log.log('MediaContentCreator#by_resource', cat: :starts)
    [Medium, Article].each do |k|
      @klass = k
      @field = "#{@klass.name.underscore.downcase}_id".to_sym
      query = @klass.where(resource: @resource.id).where(clause)
      query = query.where(['id > ?', @options[:start]]) if @options[:start]
      b_size = 1000 # Default is 1000, I just want to use this for calculation.
      count = query.count
      num_batches = (count / b_size.to_f).ceil
      @log.log("#{count} #{@klass.name.pluralize} to process (in #{num_batches} batches)", cat: :infos)
      query.find_in_batches(batch_size: b_size).with_index do |batch, number|
        @log.log("Batch #{number+1}/#{num_batches}...", cat: :infos)
        reset_batch
        learn_ancestry(batch) unless k == Article
        # TEMP: we're putting images at the bottom now so we count how many images per page...
        count_images_in(batch)
        batch.each do |content|
          add_content(content.page_id, content)
          add_ancestry_content(content) unless k == Article
        end
        # TEMP: we're putting images at the bottom now - push_pages_down
        import_contents
        update_naked_pages if k == Medium
      end
    end
    fix_counter_culture_counts(clause: clause) unless options[:skip_counts]
    if @options[:start]
      @log.log('FINISHED ... but this was a MANUAL run. If the resource has refs, YOU NEED TO PROPAGATE THE REF IDS.'\
        ' Also, technically, the temp files should be removed.', cat: :warns)
    end
  end

  def count_images_in(batch)
    pages = batch.map(&:page_id).compact.uniq
    pages -= @content_count_by_page.keys
    # NOTE: the call to #reoder helps avoid "Expression #1 of ORDER BY clause is not in GROUP BY clause and contains
    # nonaggregated column".
    counts = PageContent.where(page_id: pages).group('page_id').reorder('').count
    pages.each do |page_id|
      @content_count_by_page[page_id] = counts[page_id] || 0
    end
  end

  def learn_ancestry(batch)
    Page.includes(native_node: [:unordered_ancestors, { node_ancestors: :ancestor }])
        .where(id: batch.map(&:page_id))
        .each do |page|
          # NOTE: if we decide to have exemplar articles on pages, page.send(@field).nil? here...
          @naked_pages[page.id] = page if @field == :medium_id && page.medium_id.nil?
          @ancestry[page.id] = page.ancestry_ids
        end
  end

  def add_content(page_id, content, options = {})
    @content_count_by_page[page_id] ||= -1
    @content_count_by_page[page_id] += 1
    source = options[:source] || page_id
    @contents << { page_id: page_id, source_page_id: source, position: @content_count_by_page[page_id],
                   content_type: @klass.name, content_id: content.id, resource_id: @resource.id }
    if @naked_pages.key?(page_id)
      @naked_pages[page_id].assign_attributes(@field => content.id)
    end
  end

  def add_ancestry_content(content)
    if @ancestry.key?(content.page_id)
      @ancestry[content.page_id].each do |ancestor_id|
        add_content(ancestor_id, content, source: content.page_id) unless ancestor_id == content.page_id
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

  def fix_counter_culture_counts(options = {})
    delete = options.key?(:delete) ? options[:delete] : false
    @log.log("Fixing counter-culture counts...")
    # PageContent.where(content_type: @klass.name, content_id: @contents.map { |c| c[:content_id] }).
    #   counter_culture_fix_counts
    @resource.fix_missing_page_contents(options) # Faster.
  end
end
