module TraitBank
  class ResourceRemover
    extend TraitBank::Admin

    # NOTE: these are STRINGS, not symbols:
    STAGES = %w{begin prune_metadata meta_traits metadata inferred_traits traits vernaculars eol_pk_prefix end}

    class << self
      def remove_non_trait_content(resource)
        # 'external' metadata
        TraitBank::Admin.remove_with_query(
          name: :meta,
          q: "(meta:MetaData)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )

        TraitBank::Admin.remove_with_query(
          name: :vernacular,
          q: "(vernacular:Vernacular)-[:supplier]->(:Resource { resource_id: #{resource.id} })"
        )
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      def remove(resource, stage, size, should_republish)
        instance = self.new(resource, stage, size, should_republish)
        instance.remove
      end
    end

    def initialize(resource, stage, size, should_republish)
      @resource = resource
      @stage_name = stage
      @stage_index = STAGES.index(stage)
      @size = size || DEFAULT_REMOVAL_BATCH_SIZE
      @should_republish = should_republish
      @log = resource.log_handle
    end
  
    def next_stage
      @log.end(@stage_name)
      set_stage(@stage_index + 1)
      @size = DEFAULT_REMOVAL_BATCH_SIZE
    end

    def reduce_size
      @size ||= DEFAULT_REMOVAL_BATCH_SIZE
      @size = @size / 2
    end

    def set_stage(index)
      @stage_index = index
      @stage_name = STAGES[index]
      @log.start(@stage_name)
    end

    def remove
      if remove_complete?
        if @should_republish
          republish
        else
          end_trait_content_removal_background_jobs
        end
        return 0
      end
      
      removal_tasks = build_removal_tasks(resource)
      
      raise "Invalid stage '#{stage}' called from TraitBank::Admin#remove, exiting." if index.nil?

      if @stage_name == 'begin'
        next_stage
        log.log("Removing trait content for #{@resource.log_string}, continuing to stage #{@stage_index}: #{@stage_name}")
      end
      
      if @stage_name == 'end'
        if remove_complete?
          end_trait_content_removal_background_jobs
          republish if @should_republish
          return 0
        else
          log.log("Removal of trait content for #{resource.log_string} FAILED: there is still data in the graph, retrying...")
          set_stage(1)
          reduce_size # Try it with a smaller batch, though.
          enqueue_trait_removal_stage
        end
      elsif @stage_name == 'prune_metadata'
        prune_metadata_with_too_many_relationships(resource.id, log)
        enqueue_next_trait_removal_stage
      else
        # We're in one of the "normal" stages...
        task = removal_tasks[@stage_name].merge(log: log, size: @size)
        if count_query_results(task).zero?
          # We have already finished this stage, move on to the next.
          enqueue_next_trait_removal_stage
        else 
          # Take a chunk out of this stage:
          remove_batch_with_query(task)
          if count_query_results(task).zero?
            # This stage is done, move on to the next task:
            enqueue_next_trait_removal_stage
          else
            # There's more to do for this stage, engqueue it to continue:
            # NOTE: we pass in the size FROM THE OPTIONS, because that would have changed inside the call, if it
            # were too big or small:
            @size = task[:size] || DEFAULT_REMOVAL_BATCH_SIZE
            enqueue_trait_removal_stage
          end
        end
      end
      @log.pause
    end

    def remove_complete?
      count_nodes = count_remaining_graph_nodes
      count_pks = count_remaining_graph_pks
      @log.log("Graph nodes: #{count_nodes}, by PK: #{count_pks}")
      return false unless count_nodes.zero? && count_pks.zero?
      return true
    end
    
    def count_remaining_graph_nodes
      TraitBank::Queries.count_supplier_nodes_by_resource_nocache(@resource.id)
    end

    def count_remaining_graph_pks
      TraitBank::Queries.count_eol_pks_by_respository_id(@resource.repository_id)
    end
    
    def end_trait_content_removal_background_jobs
      msg = "There is no (remaining) trait content for #{@resource.log_string}, job complete."
      @log.log(msg)
      Rails.logger.warn(msg)
      @resource.complete
    end

    def republish
      @log.pause
      Delayed::Job.enqueue(RepublishJob.new(@resource.id, false))
    end

    def build_removal_tasks
      {
        'meta_traits' => {
          name: :meta,
          q: "(meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->(:Resource { resource_id: #{@resource.id} })"
        },
        'metadata' => {
          name: :meta,
          q: "(meta:MetaData)-[:supplier]->(:Resource { resource_id: #{@resource.id} })"
        },
        'inferred_traits' => {
          name: :rel,
          q: "()-[rel:inferred_trait]-(:Trait)-[:supplier]->(:Resource { resource_id: #{@resource.id} })"
        },
        'traits' => {
          name: :trait,
          q: "(trait:Trait)-[:supplier]->(:Resource { resource_id: #{@resource.id} })"
        },
        'vernaculars' => {
          name: :vernacular,
          q: "(vernacular:Vernacular)-[:supplier]->(:Resource { resource_id: #{@resource.id} })"
        },
        'eol_pk_prefix' => {
          name: :trait,
          q: "MATCH (trait:Trait) WHERE trait.eol_pk STARTS WITH 'R#{@resource.repository_id}-'"
        }
      }
    end

    def enqueue_next_trait_removal_stage
      next_stage
      enqueue_trait_removal_stage
    end

    def enqueue_trait_removal_stage
      msg = "Going to call background trait removal stage: #{@stage_name} for ##{@resource.log_string}"
      Rails.logger.warn(msg)
      @log.log(msg)
      Delayed::Job.enqueue(RemoveTraitContentJob.new(@resource.id, @stage_name, @size, @should_republish))
    end

    # There are some metadata nodes that have WILDLY too many relationships, and handling these as part of the "normal"
    # delete process takes AGES. To avoid this, we find them beforehand and remove those relationships one metadata node
    # at a time, which is less process-intensive.
    def prune_metadata_with_too_many_relationships(resource_id, log)
      log.log("Pruning metadata...")
      count_limit = 20_000
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
      highest_count = results['data']&.first&.last
      if highest_count < count_limit
        log.log("...No high-relationship-count metadata found (highest count: #{highest_count})")
        return 0
      end
      while highest_count && highest_count >= count_limit do
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
      TraitBank::Admin.remove_with_query(name: :r, q: %Q{(meta:MetaData {eol_pk: '#{id}'})-[r:metadata]-()})
      # Now that metadata no longer has a relationship to the resource, making it very hard to delete.
      # We remove it here to avoid having to try.
      TraitBank.query(%Q{MATCH (meta:MetaData {eol_pk: '#{id}'}) DETACH DELETE meta;})
    end
  end
end
