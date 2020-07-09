class ObjForPredRelManager
  class << self
    def rebuild
      limit = 100
      rels_created = 1
      total_rels_created = 0

      delete_query = %q(
        MATCH (o)-[r:object_for_predicate]->(p)
        DELETE r
        RETURN count(r)
      )
      puts "Nuking existing object_for_predicate relationships:\n#{delete_query}"
      delete_res = TraitBank.query(delete_query)
      puts "Response:\n#{delete_res}"
      puts "Deleted #{delete_res["data"].first.first} relationships"

      puts "Building all object_for_predicate relationships"
      while rels_created > 0
        query = %Q(
          MATCH (p:Term)<-[#{TraitBank.parent_terms}]-(:Term)<-[:predicate]-(:Trait)-[:object_term]->(:Term)-[#{TraitBank.parent_terms}]->(o:Term)
          WHERE NOT (o)-[:object_for_predicate]->(p)
          WITH DISTINCT o, p
          LIMIT #{limit}
          CREATE (o)-[r:object_for_predicate]->(p)
          RETURN count(r)
        )
        puts "Query:\n#{query}"
        response = TraitBank.query(query)
        puts "Response:\n#{response}"
        rels_created = response["data"].first.first
        total_rels_created += rels_created
      end

      puts "done -- created #{total_rels_created} relationships"
    end
  end
end
