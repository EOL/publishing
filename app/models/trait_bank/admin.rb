class TraitBank
  class Admin
    class << self
      delegate :connection, to: TraitBank
      delegate :query, to: TraitBank
      delegate :page_exists?, to: TraitBank
      delegate :relate, to: TraitBank

      def setup
        create_indexes
        create_constraints
      end

      # You only have to run this once, and it's best to do it before loading TB:
      def create_indexes
        indexes = %w{ Page(page_id) Trait(eol_pk) Trait(resource_pk) Term(uri) Term(name)
          Resource(resource_id) MetaData(eol_pk)}
        indexes.each do |index|
          begin
            query("CREATE INDEX ON :#{index};")
          rescue Neography::NeographyError => e
            if e.to_s =~ /already created/
              puts "Already have an index on #{index}, skipping."
            else
              raise e
            end
          end
        end
      end

      # NOTE: You only have to run this once, and it's best to do it before
      # loading TB:
      def create_constraints(drop = nil)
        contraints = {
          "Page" => [:page_id],
          "Term" => [:uri]
        }
        contraints.each do |label, fields|
          fields.each do |field|
            begin
              name = 'o'
              name = label.downcase if drop && drop == :drop
              query(
                "#{drop && drop == :drop ? 'DROP' : 'CREATE'} CONSTRAINT ON (#{name}:#{label}) ASSERT #{name}.#{field} IS UNIQUE;"
              )
            rescue Neography::NeographyError => e
              raise e unless e.message =~ /already exists/ || e.message =~ /No such constraint/
            end
          end
        end
      end

      # Your gun, your foot: USE CAUTION. This erases EVERYTHING irrevocably.
      def nuclear_option!
        query("MATCH (n) DETACH DELETE n")
      end

      def remove_all_data_leave_terms
        query("MATCH (meta:MetaData) DETACH DELETE meta")
        query("MATCH (trait:Trait) DETACH DELETE trait")
        query("MATCH (page:Page) DETACH DELETE page")
        query("MATCH (res:Resource) DETACH DELETE res")
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      def remove_for_resource(resource)
        query("MATCH (meta:MetaData)<-[:metadata]-(trait:Trait)-[:supplier]->"\
          "(:Resource { resource_id: #{resource.id} }) DETACH DELETE trait, meta")
        # Also need to remove traits with no metadata!
        query("MATCH (trait:Trait)-[:supplier]->(:Resource { resource_id: #{resource.id} }) DETACH DELETE trait")
        Rails.cache.clear # Sorry, this is easiest. :|
      end

      # NOTE: this code is unused, but please don't delete it; we call it manually.
      def delete_terms_in_domain(domain)
        before = query("MATCH (term:Term) WHERE term.uri =~ '#{domain}.*' RETURN COUNT(term)")["data"].first.first
        query("MATCH (term:Term) WHERE term.uri =~ '#{domain}.*' DETACH DELETE term")
        after = query("MATCH (term:Term) WHERE term.uri =~ '#{domain}.*' RETURN COUNT(term)")["data"].first.first
        raise "Not all were deleted (before: #{before}, after: #{after})" if after.positive?
        before
      end

      def delete_terms_with_no_relationships
        raise "Naw."
        # TODO: write this. I don't want to run it... there are way too many terms, I'm scare it will break s/t.
        puts query(%{MATCH (term:Term) WHERE NOT ()-->(term) AND NOT (term)-->() RETURN term.uri LIMIT 1000})["data"]
        puts query(%{MATCH (term:Term) WHERE NOT ()-->(term) AND NOT (term)-->() RETURN COUNT(term)})
      end

      # AGAIN! Use CAUTION. This is intended to DELETE all parent relationships
      # between pages, and then rebuild them based on what's currently in the
      # database. It skips relationships to pages that are missing (but reports on
      # which those are), and it does not repeat any relationships. It takes a
      # about a minute per 3000 nodes on jrice's machine.
      def rebuild_hierarchies!
        query("MATCH (:Page)-[parent:parent]->(:Page) DELETE parent")
        query("MATCH (:Page)-[in_clade:in_clade]->(:Page) DELETE in_clade")
        missing = {}
        related = {}
        # HACK HACK HACK HACK: We want to use Resource.native here, NOT ITIS!
        itis = Resource.where(name: "Integrated Taxonomic Information System (ITIS)").first
        raise " I tried to use ITIS as the native node for the relationships, but it wasn't there." unless itis
        Node.where(["resource_id = ? AND parent_id IS NOT NULL AND page_id IS NOT NULL",
          itis.id]).
          includes(:parent).
          find_each do |node|
            page_id = node.page_id
            parent_id = node.parent.page_id
            next if missing.has_key?(page_id) || missing.has_key?(parent_id)
            page = page_exists?(page_id)
            page = page.first if page
            if page
              relate("in_clade", page, page)
            end
            next if related.has_key?(page_id)
            parent = page_exists?(parent_id)
            parent = parent.first if parent
            if page && parent
              if page_id == parent_id
                puts "** OOPS! Attempted to add #{page_id} as a parent of itself!"
              else
                relate("parent", page, parent)
                relate("in_clade", page, parent)
                related[page_id] = parent_id
                # puts("#{page_id}-[:parent]->#{parent_id}")
              end
            else
              missing[page_id] = true unless page
              missing[parent_id] = true unless parent
            end
          end
        related.each do |page, parent|
          puts("#{page}-[:in_clade*]->#{parent}")
        end
        puts "Missing pages in TraitBank: #{missing.keys.sort.join(", ")}"
      end

      def rebuild_names
        query("MATCH (page:Page) REMOVE page.name RETURN COUNT(*)")
        # HACK HACK HACK HACK: We want to use Resource.native here, NOT ITIS!
        itis = Resource.where(name: "Integrated Taxonomic Information System (ITIS)").first
        Node.where(["resource_id = ?", itis.id]).find_each do |node|
          name = node.canonical_form
          page = page_exists?(node.page_id)
          next unless page
          page = page.first if page
          connection.set_node_properties(page, { "name" => name })
          puts "#{node.page_id} => #{name}"
        end
      end

      # NOTE: if you add any new caches IN THE TB CLASS, add them here.
      def clear_caches
        Rails.logger.warn("TRAITBANK CACHES CLEARED.")
        [
          "trait_bank/predicate_count",
          "trait_bank/terms_count",
          "trait_bank/predicate_glossary/count",
          "trait_bank/object_term_glossary/count",
          "trait_bank/units_term_glossary/count",
        ].each do |key|
          Rails.cache.delete(key)
        end
        count = TraitBank::Terms.count
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
