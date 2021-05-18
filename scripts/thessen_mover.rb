COMMON_Q = <<~CYPHER
  MATCH (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(mp:Term {uri:"http://purl.org/dc/terms/contributor"})
  WHERE m.literal = "Compiler: Anne E Thessen"
CYPHER

TRAIT_COUNT_Q = <<~CYPHER
  #{COMMON_Q}
  RETURN count(DISTINCT t) AS count
CYPHER

LIMIT = 1000
MIGRATE_Q = <<~CYPHER
  #{COMMON_Q}
  WITH t, collect(m) AS ms
  LIMIT 1000
  UNWIND ms AS m
  DETACH DELETE m
  WITH collect(DISTINCT t) AS ts
  MATCH (c:Term { uri: 'https://orcid.org/0000-0002-2908-3327' })
  UNWIND ts AS t
  CREATE (t)-[:compiler]->(c)
  RETURN count(t) AS count
CYPHER

initial_count = ActiveGraph::Base.query(TRAIT_COUNT_Q).first[:count]
puts "There are #{initial_count} traits with generic metadata to migrate"

batch_count = LIMIT
migrated_count = 0

while batch_count == LIMIT
  batch_count = ActiveGraph::Base.query(MIGRATE_Q).first[:count]
  migrated_count += batch_count
end

puts "Migrated #{migrated_count} traits"

if initial_count == migrated_count
  puts "Success"
else
  puts "That's not what I expected from the initial count!"
end



