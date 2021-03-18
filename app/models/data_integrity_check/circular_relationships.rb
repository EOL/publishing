# checks for circular ancestry relationships among Terms
class DataIntegrityCheck::CircularRelationships
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasPairUriDetailedReport


  private
  def query_common
    <<~CYPHER
      MATCH (t1:Term)-[:parent_term|synonym_of*1..]->(t2:Term)
      WHERE (t2)-[:parent_term|synonym_of*0..]->(t1) AND t1 <> t2
      WITH DISTINCT t1, t2
    CYPHER
  end

  def query
    <<~CYPHER
      #{query_common}
      RETURN count(*) / 2 AS count
    CYPHER
  end

  def build_count_message(count)
    "#{count} pairs of terms with circular relationship(s) found"
  end
end
