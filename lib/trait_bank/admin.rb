module TraitBank
  module Admin

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
        original_size = options[:size]
        count = 0
        log = options[:log]
        loop do
          begin
            remove_batch_with_query(options.merge(size: options[:size]))
          rescue => e
            msg = "ERROR during delete of #{options[:size]} x #{name}: #{e.message}"
            puts msg # If we're running this locally, we need to know!
            log.log(msg, cat: :warns) if log
            sleep options[:size]
            options[:size] = options[:size] / 2
            raise e if options[:size] <= 1
            retry
            options[:size] = original_size
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
        options[:size] = 16 unless options[:size].is_a?(Integer) && options[:size].positive?
        log = options[:log]
        time_before = Time.now
        apoc = "CALL apoc.periodic.iterate('MATCH #{q} WITH #{name} LIMIT #{options[:size]} RETURN #{name}', 'DETACH DELETE #{name}', { batchSize: 32 })"
        TraitBank::Logger.log("--TB_DEL: #{apoc}")
        results = TraitBank.query(apoc)
        error = apoc_errors(results)
        unless error.blank?
          raise error
        end
        time_delta = Time.now - time_before
        TraitBank::Logger.log("--TB_DEL: Took #{time_delta}.")
        # Note this is changing the ACTUAL options hash. You will GET BACK this value (via that hash)
        options[:size] *= 2 if time_delta < 15 and options[:size] <= 8192
        options[:size] /= 2 if time_delta > 30
        return options[:size]
      end
      
      def apoc_errors(results)
        results.has_key?("data") &&
        !results["data"].empty? &&
        !results["data"][0].empty? &&
        results['data'][0][-4].class == Hash &&
        results['data'][0][-4][:errors]
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
