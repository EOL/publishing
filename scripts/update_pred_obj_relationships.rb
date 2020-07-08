limit = 500
rels_created = 1
total_rels_created = 0

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
