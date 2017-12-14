class MediaContentCreator
  def self.by_resource(resource, log)
    creator = self.new(resource, log).by_resource(resource, log)
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
    Medium.where(resource: @resource.id).find_in_batches do |batch|
      reset_batch
      learn_ancestry(batch)
      batch.each do |medium|
        add_content(medium.page_id, medium)
        add_ancestry_content(medium)
      end
      push_pages_down
      import_contents
      update_naked_pages
      fix_counter_culture_counts
    end
  end

  def learn_ancestry(batch)
    Page.select(:id, :medium_id, :native_node_id)
        .includes(native_node: [:unordered_ancestors, { node_ancestors: :ancestor }])
        .where(id: batch.map(&:page_id), medium_id: nil)
        .each do |page|
          @naked_pages[page.id] = page
          @ancestry[page.id] = page.ancestry_ids
        end
  end

  def add_content(page_id, medium)
    @content_count_by_page[page_id] ||= -1
    @content_count_by_page[page_id] += 1
    @contents << { page_id: page_id, source_page_id: page_id, position: @content_count_by_page[page_id],
                   content_type: 'Medium', content_id: medium.id, resource_id: @resource.id }
    if @naked_pages.key?(page_id)
      @naked_pages[page_id].assign_attributes(medium_id: medium.id)
    end
  end

  def add_ancestry_content(medium)
    if @ancestry.key?(medium.page_id)
      @ancestry[medium.page_id].each do |ancestor_id|
        add_content(ancestor_id, medium) unless ancestor_id == medium.page_id
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
      PageContent.where(page_id: pages).update_all(['position = postion + ?', count])
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
      Page.import!(@naked_pages.values, on_duplicate_key_update: [:medium_id])
    end
  end

  def fix_counter_culture_counts
    @log.log("Fixing counter-culture counts...")
    PageContent.where(content_type: 'Medium', content_id: @contents.map(&:content_id)).counter_culture_fix_counts
  end
end
