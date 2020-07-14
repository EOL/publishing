class ObjForPredRelManager
  class << self
    def rebuild
      limit = 1000
      skip = 0

      delete_query = %q(
        MATCH (o)-[r:object_for_predicate]->(p)
        DELETE r
        RETURN count(r)
      )
      puts "Nuking existing object_for_predicate relationships:\n#{delete_query}"
      delete_res = TraitBank.query(delete_query)
      puts "Deleted #{delete_res["data"].first.first} relationships"

      count_trait_query = %q(
        MATCH (t:Trait)
        RETURN count(t)
      )
      puts "Counting traits:\n#{count_trait_query}"
      count_trait_res = TraitBank.query(count_trait_query)
      total_traits = count_trait_res["data"].first.first
      puts "Counted #{total_traits} traits"

      puts "Building all object_for_predicate relationships"
      while skip <= total_traits
        query = %Q(
          MATCH (t:Trait)
          WITH t
          SKIP #{skip}
          LIMIT #{limit}
          MATCH (p:Term)<-[#{TraitBank.parent_terms}]-(:Term)<-[:predicate]-(t)-[:object_term]->(:Term)-[#{TraitBank.parent_terms}]->(o:Term)
          MERGE (o)-[r:object_for_predicate]->(p)
          RETURN count(r)
        )
        puts "Query:\n#{query}"
        TraitBank.query(query)
        skip += limit
      end

      puts "done"

      count_query = %Q(
        MATCH (o:Term)-[:object_for_predicate]->(p:Term)
        RETURN count(*)
      )
      puts "Counting relationships:\n#{count_query}"
      rels_created_res = TraitBank.query(count_query)
      puts rels_created_res
      puts "Created a total of #{rels_created_res["data"].first.first} relationships"
    end
  end
end

