module TraitBank
  module ResourceRemover
    extend TraitBank::Admin

    # NOTE: these are STRINGS, not symbols:
    STAGES = %w{begin prune_metadata meta_traits metadata inferred_traits traits vernaculars eol_pk_prefix end}

    class << self
      def remove_non_trait_content(resource)
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

      def remove(resource, stage, size, should_republish)
        log = resource.log_handle
        if remove_complete?(resource, log)
          if should_republish
            republish(resource)
          else
            end_trait_content_removal_background_jobs(resource, log)
          end
          return 0
        end
        
        removal_tasks = build_removal_tasks(resource)
        index = STAGES.index(stage)
        raise "Invalid stage '#{stage}' called from TraitBank::Admin#remove, exiting." if index.nil?

        if stage == 'begin'
          index += 1
          stage = STAGES[index]
          log.log("Removing trait content for #{resource.log_string}, continuing to stage #{index}: #{stage}")
        end
        
        if stage == 'end'
          if remove_complete?(resource, log)
            end_trait_content_removal_background_jobs(resource, log)
            republish(resource) if should_republish
            return 0
          else
            log.log("Removal of trait content for #{resource.log_string} FAILED: there is still data in the graph, retrying...")
            enqueue_trait_removal_stage(resource.id, 1, size / 2, should_republish)
          end
        elsif stage == 'prune_metadata'
          prune_metadata_with_too_many_relationships(resource.id, log)
          enqueue_next_trait_removal_stage(resource.id, index, should_republish)
        else
          # We're in one of the "normal" stages...
          task = removal_tasks[stage].merge(log: log, size: size || DEFAULT_REMOVAL_BATCH_SIZE)
          if count_query_results(task).zero?
            # We have already finished this stage, move on to the next.
            enqueue_next_trait_removal_stage(resource.id, index, should_republish)
          else 
            # Take a chunk out of this stage:
            remove_batch_with_query(task)
            if count_query_results(task).zero?
              # This stage is done, move on to the next task:
              enqueue_next_trait_removal_stage(resource.id, index, should_republish)
            else
              # There's more to do for this stage, engqueue it to continue:
              # NOTE: we pass in the size FROM THE OPTIONS, because that would have changed inside the call, if it
              # were too big or small:
              enqueue_trait_removal_stage(resource.id, index, task[:size], should_republish)
            end
          end
        end
        log.pause
      end

      def count_remaining_graph_nodes(id)
        TraitBank::Queries.count_supplier_nodes_by_resource_nocache(id)
      end

      def count_remaining_graph_pks(repo_id)
        TraitBank::Queries.count_eol_pks_by_respository_id(repo_id)
      end

      def remove_complete?(resource, log)
        count_nodes = count_remaining_graph_nodes(resource.id)
        count_pks = count_remaining_graph_pks(resource.repository_id)
        log.log("Graph nodes: #{count_nodes}, by PK: #{count_pks}")
        return false unless count_nodes.zero? && count_pks.zero?
        return true
      end
      
      def end_trait_content_removal_background_jobs(resource, log)
        msg = "There is no (remaining) trait content for #{resource.log_string}, job complete."
        log.log(msg)
        Rails.logger.warn(msg)
        resource.complete
      end

      def republish(resource)
        resource.log_handle.pause
        Delayed::Job.enqueue(RepublishJob.new(resource.id, false))
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
          },
          'eol_pk_prefix' => {
            name: :trait,
            q: "MATCH (trait:Trait) WHERE trait.eol_pk STARTS WITH 'R#{resource.repository_id}-'"
          }
        }
      end

      def enqueue_next_trait_removal_stage(resource_id, index, should_republish = false)
        enqueue_trait_removal_stage(resource_id, index + 1, nil, should_republish)
      end

      def enqueue_trait_removal_stage(resource_id, index, size = nil, should_republish = false)
        size ||= DEFAULT_REMOVAL_BATCH_SIZE
        stage = STAGES[index]
        Rails.logger.warn("Removing TraitBank data (stage: #{stage}) for resource ##{resource_id}")
        Delayed::Job.enqueue(RemoveTraitContentJob.new(resource_id, stage, size, should_republish))
      end

      # There are some metadata nodes that have WILDLY too many relationships, and handling these as part of the "normal"
      # delete process takes AGES. To avoid this, we find them beforehand and remove those relationships one metadata node
      # at a time, which is less process-intensive.
      def prune_metadata_with_too_many_relationships(resource_id, log)
        log.log("Pruning metadata...")
        resource_id = resource_id.to_i
        query = %Q{
          MATCH (meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource_id} })
          WITH DISTINCT meta
          MATCH (meta)-[r]-()
          WITH meta, count(DISTINCT r) AS rel_count
          RETURN meta.eol_pk, rel_count
          ORDER BY rel_count DESC
          LIMIT 20
        }
        # This can take a few seconds...
        results = TraitBank.query(query)
        unless results.has_key?('data') # Something went really wrong.
          log.log("WARNING: metadata relationship query had no 'data' key: #{query}")
          log.log("Response keys: #{results.keys}")
          return nil
        end
        removed = 0
        while results['data']&.first&.last && results['data'].first.last > 20_000 do
          result = results['data'].shift
          eol_pk = result.first
          rel_count = result.last
          remove_metadata_relationships(eol_pk, rel_count)
          removed += rel_count
        end
        log.log("...removed approximately #{removed} metadata relationships.")
        return removed
      end

      def remove_metadata_relationships(id, count)
        # puts "#{id} has #{count} relationships."
        remove_with_query(name: :r, q: %Q{(meta:MetaData {eol_pk: '#{id}'})-[r:metadata]-()})
        # Now that metadata no longer has a relationship to the resource, making it very hard to delete.
        # We remove it here to avoid having to try.
        TraitBank.query(%Q{MATCH (meta:MetaData {eol_pk: '#{id}'}) DETACH DELETE meta;})
      end
      end
  end
end
