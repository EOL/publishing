module TraitBank
  module Admin

    # NOTE: these are STRINGS, not symbols:
    STAGES = %w{begin prune_metadata meta_traits metadata inferred_traits traits vernaculars end}
    DEFAULT_REMOVAL_BATCH_SIZE = 64

    class << self
      def setup
        create_indexes
        create_constraints
      end

      # You only have to run this once, and it's best to do it before loading TB:
      def create_indexes
        indexes = %w{ Term(name) }
        indexes.each do |index|
          TraitBank.query("CREATE INDEX ON :#{index};")

          # TraitBank.query no longer uses Neography. Preserving in case this is needed.
          # - mvitale
          #rescue Neography::NeographyError => e
          #  if e.to_s =~ /already created/
          #    puts "Already have an index on #{index}, skipping."
          #  else
          #    raise e
          #  end
          #end
        end
      end

      # NOTE: You only have to run this once, and it's best to do it before
      # loading TB:
      def create_constraints(drop = nil)
        contraints = {
          "Page" => [:page_id],
          "Term" => [:uri, :eol_id],
          "Trait" => [:eol_pk],
          "Resource" => [:resource_id],
          "MetaData" => [:eol_pk]
        }
        contraints.each do |label, fields|
          fields.each do |field|
            name = 'o'
            name = label.downcase if drop && drop == :drop
            # You cannot have an index on a constrained field. Sorry about the rescue nil, this is a MINOR operation
            # and it throws an error if the index doesn't exist:
            TraitBank.query("DROP INDEX ON :#{label}(#{field})") rescue nil

            constraint_query = "#{drop && drop == :drop ? 'DROP' : 'CREATE'} CONSTRAINT ON (#{name}:#{label}) ASSERT #{name}.#{field} IS UNIQUE;"
            puts constraint_query
            puts TraitBank.query(constraint_query)

            # Same as above.
            #rescue Neography::NeographyError => e
            #  raise e unless e.message =~ /already exists/ || e.message =~ /No such constraint/
            #end
          end
        end
      end

      # Your gun, your foot: USE CAUTION. This erases EVERYTHING irrevocably.
      def nuclear_option!
        remove_with_query(name: :n, q: "(n)")
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      # Your gun, your foot: USE CAUTION. This erases (almost) EVERYTHING irrevocably.
      def remove_all_data_leave_terms!
        remove_with_query(name: :meta, q: "(meta:MetaData)")
        remove_with_query(name: :trait, q: "(trait:Trait)")
        remove_with_query(name: :page, q: "(page:Page)")
        remove_with_query(name: :res, q: "(res:Resource)")
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      def remove_non_trait_content_for_resource(resource)
        # 'external' metadata
        remove_with_query(
          name: :meta,
          q: "(meta:MetaData)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )

        remove_with_query(
          name: :vernacular,
          q: "(vernacular:Vernacular)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      def count_remaining_graph_nodes(id)
        TraitBank::Queries.count_supplier_nodes_by_resource_nocache(id)
      end

      def end_trait_content_removal_background_jobs(resource, log)
        msg = "There is no (remaining) trait content for #{resource.log_string}, job complete."
        log.log(msg)
        Delayed::Worker.logger.info(msg)
        resource.complete
      end

      def remove_by_resource_complete?(resource, log)
        count = count_remaining_graph_nodes(resource.id)
        return false unless count.zero?
        end_trait_content_removal_background_jobs(resource, log)
        return true
      end

      def remove_by_resource(resource, stage, size)
        log = resource.log_handle
        return 0 if remove_by_resource_complete?(resource, log)
        
        removal_tasks = build_removal_tasks(resource)
        index = STAGES.index(stage)
        raise "Invalid stage '#{stage}' called from TraitBank::Admin#remove_by_resource, exiting." if index.nil?

        if stage == 'begin'
          log.log("Removing trait content for #{resource.log_string}...")
          index += 1
          stage = STAGES[index]
        end
        
        if stage == 'end'
          return end_trait_content_removal_background_jobs(resource, log) if remove_by_resource_complete?(resource, log)
          log.log("Removal of trait content for #{resource.log_string} FAILED: there is still data in the graph, retrying...")
          enqueue_trait_removal_stage(resource.id, 1)
        elsif stage == 'prune_metadata'
          prune_metadata_with_too_many_relationships(resource.id)
          enqueue_next_trait_removal_stage(resource.id, index)
        else
          # We're in one of the "normal" stages...
          task = removal_tasks[stage].merge(log: log, size: size || DEFAULT_REMOVAL_BATCH_SIZE)
          if count_query_results(task).zero?
            # We have already finished this stage, move on to the next.
            enqueue_next_trait_removal_stage(resource.id, index)
          else 
            # Take a chunk out of this stage:
            remove_batch_with_query(task)
            if count_query_results(task).zero?
              # This stage is done, move on to the next task:
              enqueue_next_trait_removal_stage(resource.id, index)
            else
              # There's more to do for this stage, engqueue it to continue:
              # NOTE: we pass in the size FROM THE OPTIONS, because that would have changed inside the call, if it
              # were too big or small:
              enqueue_trait_removal_stage(resource.id, index, task[:size])
            end
          end
        end
      end

      def build_removal_tasks(resource)
        {
          'meta_traits' => {
            name: :meta,
            q: "(meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
          },
          'metadata' => {
            name: :meta,
            q: "(meta:MetaData)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
          },
          'inferred_traits' => {
            name: :rel,
            q: "()-[rel:inferred_trait]-(:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
          },
          'traits' => {
            name: :trait,
            q: "(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
          },
          'vernaculars' => {
            name: :vernacular,
            q: "(vernacular:Vernacular)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
          }
        }
      end

      def enqueue_next_trait_removal_stage(resource_id, index, size = nil)
        enqueue_trait_removal_stage(resource_id, index + 1, size)
      end

      def enqueue_trait_removal_stage(resource_id, index, size = nil)
        size ||= DEFAULT_REMOVAL_BATCH_SIZE
        stage = STAGES[index]
        Delayed::Worker.logger.info("Removing TraitBank data (stage: #{stage}) for resource ##{resource_id}")
        Delayed::Job.enqueue(RemoveTraitContentJob.new(resource_id, stage, size))
      end

      # There are some metadata nodes that have WILDLY too many relationships, and handling these as part of the "normal"
      # delete process takes AGES. To avoid this, we find them beforehand and remove those relationships one metadata node
      # at a time, which is less process-intensive.
      def prune_metadata_with_too_many_relationships(resource_id)
        resource_id = resource_id.to_i
        results = TraitBank.query(%Q{
          MATCH (meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource_id} })
          WITH DISTINCT meta
          MATCH (meta)-[r]-()
          WITH meta, count(DISTINCT r) AS rel_count
          RETURN meta.eol_pk, rel_count
          ORDER BY rel_count DESC
          LIMIT 20
        }) # This can take a few seconds...
        return nil unless results.has_key?('data') # Something went really wrong.
        removed = 0
        while results['data']&.first&.last && results['data'].first.last > 20_000 do
          result = results['data'].shift
          eol_pk = result.first
          rel_count = result.last
          remove_metadata_relationships(eol_pk, rel_count)
          removed += rel_count
        end
        return removed
      end

      def remove_metadata_relationships(id, count)
        # puts "#{id} has #{count} relationships."
        remove_with_query(name: :r, q: %Q{(meta:MetaData {eol_pk: '#{id}'})-[r:metadata]-()})
        # Now that metadata no longer has a relationship to the resource, making it very hard to delete.
        # We remove it here to avoid having to try.
        TraitBank.query(%Q{MATCH (meta:MetaData {eol_pk: '#{id}'}) DETACH DELETE meta;})
      end

      def remove_trait_and_metadata(eol_pk)
        ActiveGraph::Base.query(
          'MATCH (t:Trait{ eol_pk: $eol_pk })-[:metadata]->(m:MetaData) DETACH DELETE m',
          eol_pk: eol_pk
        )

        ActiveGraph::Base.query(
          'MATCH (t:Trait{ eol_pk: $eol_pk }) DETACH DELETE t',
          eol_pk: eol_pk
        )
      end

      # options = {name: :meta, q: "(meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: 640 })"}
      def remove_with_query(options = {})
        delay = options[:delay] || 1 # Increasing this did not really help site performance. :|
        count_before = count_query_results(options)
        return if count_before.nil? || ! count_before.positive?
        name = options[:name]
        options[:size] ||= DEFAULT_REMOVAL_BATCH_SIZE
        count = 0
        log = options[:log]
        loop do
          begin
            remove_batch_with_query(options.merge(size: options[:size]))
          rescue => e
            log.log("ERROR during delete of #{options[:size]} x #{name}: #{e.message}", cat: :warns) if log
            sleep options[:size]
            options[:size] = options[:size] / 2
            retry unless options[:size] <= 16
          end
          count += options[:size]
          if count >= count_before
            count = count_by_query(name, options[:q])
            break unless count.positive?
            if count >= 2 * count_before
              raise "I have been attempting to delete #{name} data for twice as long as expected. "\
                    "Started with #{count_before} entries, now there are #{count}. Aborting."
            end
          end
          sleep(delay)
        end
      end

      def remove_batch_with_query(options = {})
        name = options[:name]
        q = invert_quotes(options[:q])
        options[:size] ||= DEFAULT_REMOVAL_BATCH_SIZE
        log = options[:log]
        time_before = Time.now
        apoc = "CALL apoc.periodic.iterate('MATCH #{q} WITH #{name} LIMIT #{options[:size]} RETURN #{name}', 'DETACH DELETE #{name}', { batchSize: 32 })"
        TraitBank::Logger.log("--TB_DEL: #{apoc}")
        TraitBank.query(apoc)
        time_delta = Time.now - time_before
        TraitBank::Logger.log("--TB_DEL: Took #{time_delta}.")
        # Note this is changing the ACTUAL options hash. You will GET BACK this value (via that hash)
        options[:size] *= 2 if time_delta < 15 and options[:size] <= 8192
        options[:size] /= 2 if time_delta > 30
        return options[:size]
      end
      
      def count_query_results(options)
        name = options[:name]
        q = invert_quotes(options[:q])
        count_by_query(name, q)
      end

      def invert_quotes(str)
        str.
          gsub('"', 'QUOTED_SINGLE_QUOTE').
          gsub("'", '"').
          gsub('QUOTED_SINGLE_QUOTE', "\\\\'") # Boy I hate that \\\\ syntax.
      end

      def count_by_query(name, q)
        TraitBank.query("MATCH #{q} RETURN COUNT(DISTINCT #{name})")['data']&.first&.first
      end

      # NOTE: this code is unused, but please don't delete it; we call it manually.
      def delete_terms_in_domain(domain)
        before = TraitBank.query("MATCH (term:Term) WHERE term.uri =~ '#{domain}.*' RETURN COUNT(term)")["data"].first.first
        remove_with_query(name: :term, q: "(term:Term) WHERE term.uri =~ '#{domain}.*'")
        before
      end

      def delete_terms_with_no_relationships
        raise "Naw." # TODO: See if this works properly (in a test graph), then remove this line.
        remove_with_query(name: :term, q: "(term:Term) WHERE NOT ()-->(term) AND NOT (term)-->()")
      end

      # AGAIN! Use CAUTION. This is intended to delete all parent relationships between pages, and then rebuild them
      # based on what's currently in the database. It skips relationships to pages that are missing (but reports on
      # which those are), and it does not repeat any relationships. It takes a about a minute per 3000 nodes on jrice's
      # machine.
      def rebuild_hierarchies(remove_old = false)
        if remove_old
          remove_with_query(name: :parent, q: "(:Page)-[parent:parent]->(:Page)")
        end
        related = {}
        eol = Resource.native
        raise "I tried to use EOL as the native node for the relationships, but it wasn't there." unless eol
        nodes = Node.where(["resource_id = ? AND parent_id IS NOT NULL AND page_id IS NOT NULL", eol.id])
        count = nodes.count
        per_cent = count / 100
        i = 0
        dumb_log('Starting')
        nodes.includes(:parent).find_each do |node|
          i += 1
          pct_complete = ((i / count.to_f) * 100).ceil
          dumb_log("Percent complete: #{pct_complete}% (#{i}/#{count})") if (i % per_cent).zero?
          page_id = node.page_id
          next if node.parent.nil?
          parent_id = node.parent.page_id
          next if page_id == parent_id
          next if related.key?(page_id) # Pages may only have ONE parent.
          tries = 0
          begin
            res = TraitBank.query("MERGE (from_page:Page { page_id: #{page_id}}) "\
              "MERGE (to_page:Page { page_id: #{parent_id}}) "\
              "MERGE(from_page)-[:parent]->(to_page)")
          rescue
            tries += 1
            raise "Too many retries to relate page #{page_id} to its parent #{parent_id}!" if tries >= 10
            sleep(tries)
            retry
          end
          related[page_id] = parent_id
        end
        dumb_log('Done.')
      end

      def dumb_log(what)
        puts "[#{Time.now}] #{what}"
        STDOUT.flush
      end

      def rebuild_names
        TraitBank.query("MATCH (page:Page) REMOVE page.name RETURN COUNT(*)")
        dynamic_hierarchy = Resource.native
        Node.where(["resource_id = ?", dynamic_hierarchy.id]).find_each do |node|
          name = node.canonical_form
          page = PageNode.where(page_id: node.page_id)&.first
          next unless page
          page.update!(name: name)
          puts "#{node.page_id} => #{name}"
        end
      end

      # NOTE: if you add any new caches IN THE TB CLASS, add them here.
      def clear_caches
        TraitBank::Logger.warn("TRAITBANK CACHES CLEARED.")
        [
          "trait_bank/predicate_count",
          "trait_bank/terms_count",
          "trait_bank/predicate_glossary/count",
          "trait_bank/object_term_glossary/count",
          "trait_bank/units_term_glossary/count",
        ].each do |key|
          Rails.cache.delete(key)
        end
        count = TraitBank::Term.count
        # NOTE: unfortunately, we don't KNOW here how many there are per page.
        # Yech! Perhaps a Rails config?
        lim = (count / Rails.configuration.data_glossary_page_size.to_f).ceil
        (0..lim).each do |index|
          Rails.cache.delete("trait_bank/full_glossary/#{index}")
          Rails.cache.delete("trait_bank/predicate_glossary/#{index}")
          Rails.cache.delete("trait_bank/object_term_glossary/#{index}")
          Rails.cache.delete("trait_bank/units_term_glossary/#{index}")
        end
        Resource.pluck(:id).each do |id|
          Rails.cache.delete("trait_bank/count_by_resource/#{id}")
          # NOTE: there's also a resource-by-page, but... that's waaaaay too much work to do here.
        end
        true
      end
    end
  end
end
