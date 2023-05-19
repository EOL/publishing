class MediaContentCreator
  class << self
    def by_resource(resource, options = {})
      self.new(resource, options[:log], start: options[:id]).by_resource(options)
    end
  end

  def initialize(resource, log = nil, options = {})
    @resource = resource
    @log = log || ImportLog.where(resource_id: @resource.id).last
    @options = options
  end

  def reset_batch
    @contents = []
    @all_pages = {}
    @naked_pages = {}
    @ancestry = {}
    @position_by_page = {}
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
        learn_ancestry(batch) unless @klass == Article
        # TEMP: we're putting images at the bottom now so we count how many images per page...
        find_media_position_max_by_page(batch)
        batch.each do |content|
          add_content(content.page_id, content)
          add_ancestry_content(content) unless k == Article
        end
        # HOLD, slow: push_content_down
        import_contents
        update_naked_pages if k == Medium
      end
      # TEMP: we're putting images at the bottom now - push_pages_down
      import_contents
      update_naked_pages if @klass == Medium
    end
  end

  def by_media_ids(media_ids)
    @klass = Medium
    @field = :medium_id
    add_content_in_batches_for(Medium.where(resource: @resource.id, id: media_ids.to_a))
  end
  
  def by_article_ids(article_ids)
    @klass = Article
    @field = :article_id
    add_content_in_batches_for(Medium.where(resource: @resource.id, id: article_ids.to_a))
  end

  def find_media_position_max_by_page(batch)
    pages = batch.map(&:page_id).compact.uniq
    pages -= @position_by_page.keys
    # NOTE: the call to #reoder helps avoid "Expression #1 of ORDER BY clause is not in GROUP BY clause and contains
    # nonaggregated column".
    counts = PageContent.where(page_id: pages, content_type: @klass.name).group('page_id').reorder('').maximum(:position)
    pages.each do |page_id|
      # This is a (slow) stop-gap method to find missing icons:
      if !counts.key(page_id)
        next unless Page.exists?(page_id)
        counts[page_id] = PageContent.where(page_id: page_id, content_type: @klass.name).maximum(:position) || 0
      end 
      @naked_pages[page_id] ||= Page.find(page_id) if counts[page_id]&.zero?
    end
  end

  def find_media_position_max_for_page_id(page_id)
    pos = PageContent.where(page_id: page_id, content_type: @klass.name).maximum(:position) || 0
    @position_by_page[page_id] = pos
    pos
  end

  def insert_images_after(img_count)
    return 0 if img_count.nil?
    return 0 if img_count.zero?
    1 # This will put all new images after the *existing* first image (which should preserve thumbnails).
  end

  def learn_ancestry(batch)
    Page.includes(native_node: [:unordered_ancestors, { node_ancestors: :ancestor }]).
        where(id: batch.map(&:page_id)).
        each do |page|
          @all_pages[page.id] ||= page 
          # NOTE: if we decide to have exemplar articles on pages, page.send(@field).nil? here...
          @naked_pages[page.id] = page if @klass == Medium && page.medium_id.nil?
          @ancestry[page.id] = page.ancestry_ids
        end
  end

  def add_content(page_id, content, options = {})
    @position_by_page[page_id] ||= find_media_position_max_for_page_id(page_id)
    @position_by_page[page_id] += 1
    source = options[:source] || page_id
    @contents << { page_id: page_id, source_page_id: source, position: @position_by_page[page_id],
                   content_type: @klass.name, content_id: content.id, resource_id: @resource.id }
    if @naked_pages.key?(page_id) && content.image? && content.subclass == Medium.subclasses[:image]
      mc = @naked_pages[page_id].media.count # Note this is kind of expensive. :\
      @naked_pages[page_id].assign_attributes(medium_id: content.id, media_count: mc)
    end
  end

  def add_ancestry_content(content)
    if @ancestry.key?(content.page_id)
      @ancestry[content.page_id].each do |ancestor_id|
        add_content(ancestor_id, content, source: content.page_id) unless ancestor_id == content.page_id
      end
    end
  end

  def push_content_down
    @log.log("Pushing contents down...")
    push_pages = {}
    @position_by_page.each do |page_id, count|
      push_pages[count] ||= []
      push_pages[count] << page_id
    end
    push_pages.each do |count, pages|
      next if count.nil? || count.zero?
      PageContent.where(page_id: pages, content_type: @klass.name).update_all(['position = position + ?', count])
    end
  end

  def import_contents
    # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
    # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
    @log.log("import #{@contents.size} page contents e.g.: PageContent.find_by(page_id:#{@contents.first[:page_id]},content_type:#{@contents.first[:content_type]},content_id:#{@contents.first[:content_id]})")
    PageContent.import(@contents, on_duplicate_key_ignore: true)
  end

  def update_naked_pages
    if @naked_pages.empty?
      @log.log("Zero pages had no images and now have at least one. Skipping adding of icons...")
    else
      @log.log("updating #{@naked_pages.values.size} pages with icons e.g.: Page.find(#{@naked_pages.values.first.id})")
      Page.import!(@naked_pages.values, on_duplicate_key_update: [@field])
    end
  end

  def update_page_counts
    @log.log("Fixing counts on #{@all_pages.keys.count} pages...")
    @all_pages.keys.in_groups_of(1200) do |page_ids|
      counts = PageContent.where(page_id: page_ids, content_type: 'Article').reorder(nil).group(:page_id).count
      counts.keys.each do |page_id|
        puts page_id # @all_pages[page_id] ||= Page.find(page_id) # Shouldn't be needed, but juuuuust in case
        @all_pages[page_id].articles_count = counts[page_id]
      end
      Page.import(@all_pages.values, on_duplicate_key_update: [:articles_count])
    end
  end
end
