class Node
  class Mover
    class << self
      # Assumes you are passing in a list of node_pks with their new page ids as a (single) value.
      def by_hash(resource, nodes_to_pages)
        # Update all of the nodes, duh

        # Rebuild the ancestry

        # Update the denormalized page ids on identifiers, node_ancestors, pages, scientific_names, taxon_remarks, and
        # vernaculars

        # Rebuild page contents

        # Update page metadata (counts, scores)

        # Check page native_nodes for changes...

        #
      end
    end
  end
end
