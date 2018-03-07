class PageCreator
  # NOTE: You probably want to follow this with { Node.where(resource_id: @resource.id).counter_culture_fix_counts } (or
  # something like it)
  def self.by_node_pks(node_pks, log, options = {})
    log.log('create_new_pages')
    node_id_by_page = {}
    # CREATE NEW PAGES: TODO: we need to recognize DWH and allow it to have its pages assign the native_node_id to it,
    # regardless of other nodes. (Meaning: if a resource creates a weird page, the DWH later recognizes it and assigns
    # itself to that page, then the native_node_id should *change* to the DWH id.)
    have_pages = []
    node_pks.in_groups_of(1000, false) do |group|
      page_ids = []
      Node.where(resource_pk: group).select("id, page_id").find_each do |node|
        node_id_by_page[node.page_id] = node.id
        page_ids << node.page_id
      end
      have_pages += Page.where(id: page_ids).pluck(:id)
    end
    missing = node_id_by_page.keys - have_pages
    pages = missing.map { |id| { id: id, native_node_id: node_id_by_page[id], nodes_count: 1 } }
    if pages.empty?
      log.log('There were NO new pages, skipping...', cat: :warns)
      return
    end
    pages.in_groups_of(1000, false) do |group|
      log.log("importing #{group.size} Pages", cat: :infos)
      # NOTE: these are supposed to be "new" records, so the only time there are duplicates is during testing, when I
      # want to ignore the ones we already had (I would delete things first if I wanted to replace them):
      Page.import!(group, on_duplicate_key_ignore: true)
    end
    if options[:skip_reindex]
      log.log('Skipping reindexing. You should reindex soon.', cat: :warns)
    else
      log.log('Reindexing new pages...')
      missing.in_groups_of(10_000, false) { |group| Page.where(id: group).reindex }
    end
    # TODO: This *shouldn't* be needed. The pages we created have native nodes assigned above, and existing pages should
    # have been fine. But we keep seeing this happen, so there's a bug in the harvester's publishing code... ?
    log.log('Fixing native nodes...')
    bad_natives = Page.where(native_node_id: nil, id: missing).pluck(:id)
    bad_natives.in_groups_of(10_000, false) do |group|
      Page.fix_native_nodes(Page.where(native_node_id: nil, id: group))
    end
    # TODO: Fix counter-culture counts on affected pages. :\
  end
end
