class Node
  class Mover
    class << self
      # Assumes you are passing in a list of node_pks with their new page ids as a (single) value.
      def by_hash(resource, nodes_to_pages)
        page_changes = {}
        nodes_to_pages.keys.in_groups_of(5000, false) do |pks|
          nodes = Node.where(resource_pk: pks)
          # re-arrange them into a hash:
          nodes_by_pk = {}
          nodes.each { |node| nodes_by_pk[node.resource_pk] = node }
          # Update all of the nodes, duh
          updated = []
          pks.each do |pk|
            from_page_id = nodes_by_pk[pk].page_id
            to_page_id = nodes_to_pages[pk]
            if from_page_id != to_page_id
              page_changes[from_page_id] = to_page_id
              nodes_by_pk[pk].page_id = to_page_id
              updated << nodes_by_pk[pk]
            end
          end
          Node.import!(updated, on_duplicate_key_update: [:page_id])
        end

        # Rebuild the ancestry TODO - whatever script calls this will be responsible. Easiest to "Import" it from the
        # harvester.

        # Update the denormalized page ids on identifiers, scientific_names, taxon_remarks, and vernaculars
        [Identifier, ScientificName, TaxonRemark, Vernacular].each do |klass|
          # Meh, let's just update them in (potentially) batches. This may be less efficient than import!, but it's far
          # less code and clearer for maintainance:
          page_changes.each do |from_page_id, to_page_id|
            klass.where(resource_id: resource.id, page_id: from_page_id).update_all(to_page_id)
          end
        end

        # Rebuild PageContent instances...

        # Update page metadata (counts, scores)

        # Check page native_nodes for changes...

        # More?
      end
    end
  end
end
