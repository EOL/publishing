class PageCreator
  # NOTE: You probably want to follow this with { Node.where(resource_id: @resource.id).counter_culture_fix_counts } (or
  # something like it)
  def self.by_node_pks(node_pks, log, options = {})
    log.log('create_new_pages')
    
    # Process everything in small batches. This prevents building massive
    # arrays or hashes in memory.
    node_pks.in_groups_of(1000, false) do |group|
      node_id_by_page = {}
      
      Node.where(resource_pk: group).pluck(:id, :page_id).each do |id, page_id|
        node_id_by_page[page_id] = id
      end
      
      target_page_ids = node_id_by_page.keys
      next if target_page_ids.empty?

      existing_page_ids = Page.where(id: target_page_ids).pluck(:id)
      missing_page_ids = target_page_ids - existing_page_ids

      next if missing_page_ids.empty?

      pages_to_import = missing_page_ids.map do |id| 
        { id: id, native_node_id: node_id_by_page[id], nodes_count: 1 } 
      end

      Page.import!(pages_to_import, on_duplicate_key_ignore: true)

      unless options[:skip_reindex]
        Page.where(id: missing_page_ids).reindex
      end

      Page.fix_missing_native_nodes(Page.where(native_node_id: nil, id: missing_page_ids))
    end
    # TODO: Fix counter-culture counts on affected pages. :\
  end
end
