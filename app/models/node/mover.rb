class Node
  class Mover
    # TODO: refactor. This is super-sloppy
    # TODO: logging
    class << self
      def by_resource(resource)
        require 'csv'
        # Go grab the file from beta-repo
        publisher = Publishing::Fast.new(resource)
        # You must specify the data file to write to before calling #grab_file #TODO: perhaps it should be an arg, eh?
        data_file = Rails.root.join('tmp', "#{resource.abbr}_nodes_remap.csv")
        publisher.data_file = data_file
        log = Publishing::PubLog.new(resource)
        begin
          log.log("START: Move Nodes", cat: :starts)
          publisher.log = log
          publisher.grab_file('nodes_remap.csv')
          # Parse the file to pull out the PK (1st col) and map that to the page (third col); WE IGNORE COLUMN 2 (which,
          # FTR, was the page the harvester thought the node *used* to be on, but we don't trust that. It's archival.)
          nodes_to_pages = {}
          CSV.read(data_file).each do |line|
            nodes_to_pages[line.first] = line.last.to_i
          end
          # Then do it to it:
          by_hash(resource, nodes_to_pages, log)
        rescue => e
          log.fail_on_error(e)
          raise e
        ensure
          log.complete
          File.unlink(data_file)
        end
      end

      # Assumes you are passing in a list of node_pks with their new page ids as a (single) value.
      def by_hash(resource, nodes_to_pages, log = nil)
        pages_that_lost_native_node = []
        page_changes = {}
        new_pages = {}
        nodes_by_pk = {}
        log ||= resource.import_logs.last

        # Update all of the nodes, duh
        nodes_to_pages.keys.in_groups_of(2000, false) do |pks|
          log.log("nodes to pages group of #{pks.size}", cat: :starts)
          nodes = Node.where(resource_id: resource.id, resource_pk: pks).includes(:page)
          node_page = {}
          # re-arrange them into a hash:
          nodes.each { |node| nodes_by_pk[node.resource_pk] = node ; node_page[node.resource_pk] = node.page }
          updated = []
          pks.each do |pk|
            from_page_id = nodes_by_pk[pk].page_id
            to_page_id = nodes_to_pages[pk]
            if nodes_by_pk[pk].nil?
              puts "OOPS! I can't find a node with the PK '#{pk}'"
              next
            end
            if from_page_id != to_page_id
              page_changes[from_page_id] ||= 0
              page_changes[from_page_id] -= 1
              page_changes[to_page_id] ||= 0
              page_changes[to_page_id] += 1
              new_pages[to_page_id] ||= nodes_by_pk[pk].id # NOTE: will take the first one, if several. This is OK.
              nodes_by_pk[pk].page_id = to_page_id
              updated << nodes_by_pk[pk]
            end
            pages_that_lost_native_node << from_page_id if node_page[pk]&.native_node_id == nodes_by_pk[pk].id
          end
          log.log("Importing #{updated.size}", cat: :infos)
          Node.import!(updated, on_duplicate_key_update: [:page_id])
        end

        # Create pages that didn't exist:
        new_pages.keys.in_groups_of(1000, false) do |group|
          new_pages = group - Page.where(id: group).pluck(:id)
          new_pages.each do |id|
            Page.create(id: id, native_node_id: new_pages[id])
          end
        end

        # Update the denormalized page ids on scientific_names and vernaculars
        affected_nodes_by_id = {}
        nodes_by_pk.values.each { |node| affected_nodes_by_id[node.id] = node.page_id }
        [ScientificName, Vernacular].each do |klass|
          log.log("Fixing #{klass}", cat: :starts)
          affected_nodes_by_id.keys.in_groups_of(2000, false) do |group|
            instances = klass.where(resource_id: resource.id, node_id: group)
            instances.each do |instance|
              instance.page_id = affected_nodes_by_id[instance.node_id]
            end
          end
        end

        # TODO: Update traits. This will not be simple, because traits do NOT retain a node_id for their source. You
        # might be able to "fake" this by using the supplied scientific name from the node, but that is perhaps a little
        # sketchy. It might be best for the harvesting end to supply a list of Trait eol_pks that move from page to
        # page. This Cypher isn't finished, clearly, but it's handy enough that I'm keeping it here...
        # %{(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })}

        page_changes_csv = Rails.root.join('tmp', "#{resource.abbr}_page_changes.csv")
        # Let's store the pages affected as well as the change count, so we don't lose them.
        CSV.open(page_changes_csv, 'wb') do |csv|
          page_changes.each { |page, change| csv << [page, change] }
        end

        pages = page_changes.keys.uniq
        pages.in_groups_of(1000, false) do |group|
          # Rebuild PageContent instances... this also updates page media_count, link_count, articles_count, and
          # page_contents_count
          log.log("MediaContentCreator for #{group.size} pages (starting with #{group.first})...", cat: :starts)
          # NOTE: skipping counts here because we are better-suited to do it ourselves!
          MediaContentCreator.by_resource(resource, clause: { id: group }, skip_counts: true)

          #  ...Skipping these for now because it's expensive and not terribly useful:
          # TODO: "vernaculars_count"
          # TODO: "scientific_names_count"
          # TODO: "referents_count"
        end
        File.unlink(page_changes_csv)

        # Update nodes_count on pages.
        log.log("Updating nodes counts...", cat: :starts)
        page_changes_by_count =
          page_changes.each_with_object({}) do |(key,value),out|
            out[value] ||= []
            out[value] << key
          end
        page_changes_by_count.each do |count, page_ids|
          next if count == 0
          sign = count.positive? ? '+' : '-'
          Page.where(id: page_ids).update_all("nodes_count = nodes_count #{sign} #{count.abs}")
        end

        # Fix pages that lost their native node...
        if pages_that_lost_native_node.any?
          log.log("Fixing missing native nodes on #{pages_that_lost_native_node.size} pages...", cat: :starts)
          Page.where(id: pages_that_lost_native_node).includes(:nodes).find_each do |page|
            page.update_attribute(:native_node_id, page.nodes&.first&.id)
            # TODO: delete the page instead, if the nodes are now empty.
          end
        end

        log.log("END: Move Nodes", cat: :ends)
      end
    end
  end
end
