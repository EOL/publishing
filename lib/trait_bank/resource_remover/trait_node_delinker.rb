module TraitBank
  class ResourceRemover
    class TraitNodeDelinker
      
      class << self
        def delink(query, log)
          delinker = self.new(query, log)
          delinker.make_dead_nodes_invisible
        end
      end

      def initialize(query, log)
        @query = query
        @failures = {}
        @log = log
      end

      def make_dead_nodes_invisible
        @log.log("Removing page links from immutable trait nodes (make dead nodes 'invisible')...")
        # @query is something like: "(trait:Trait) WHERE trait.eol_pk STARTS WITH \"R578-\""
        ordered_query = "MATCH #{@query} WITH trait LIMIT 1 RETURN trait.eol_pk ORDER BY trait.eol_pk"
        first_pk = TraitBank.query(ordered_query)['data'].first.first
        last_pk  = TraitBank.query("#{@query} DESC")['data'].first.first
        resource_key = first_pk.sub(/-PK.*$/, '')
        first_id = first_pk.sub(/R\d+-PK/, '').to_i
        last_id  =  last_pk.sub(/R\d+-PK/, '').to_i
        current_id = first_id
        while current_id < last_id
          make_node_invisible(resource_key, current_id)
          current_id += 1
        end
        log_failures unless @failures.empty?
      end
      
      def make_node_invisible(resource_key, current_id)
        eol_pk = "#{resource_key}-PK#{current_id}"
        begin
          delete_trait(eol_pk)
        rescue Neo4j::Driver::Exceptions::DatabaseException => e
          delete_trait_to_page_relationship(eol_pk)
        end
      end
      
      def delete_trait(eol_pk)
        TraitBank.query(%Q{MATCH (trait:Trait)<--(:Page) WHERE trait.eol_pk = "#{eol_pk}" DETACH DELETE trait})
      end
      
      def delete_trait_to_page_relationship(eol_pk)
        begin
          TraitBank.query(%Q{MATCH (trait:Trait)<-[rel]-(page:Page) WHERE trait.eol_pk = "#{eol_pk}" DELETE rel})
        rescue Neo4j::Driver::Exceptions::DatabaseException => e
          @failures[eol_pk] = true
        end
      end
      def log_failures
        @failures.keys.in_groups_of(100) do |group|
          @log.log("UNABLE TO REMOVE OR MAKE INVISIBLE: #{group.join(',')}") 
        end
      end
    end
  end
end

