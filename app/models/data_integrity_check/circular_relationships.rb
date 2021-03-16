# checks for circular ancestry relationships among Terms
class DataIntegrityCheck::CircularRelationships
  QUERY = %{
    MATCH (t1:Term)-[:parent_term|synonym_of*1..]->(t2:Term)
    WHERE (t2)-[:parent_term|synonym_of*0..]->(t1) AND t1 <> t2
    WITH DISTINCT t1, t2
    RETURN count(*) / 2 AS count
  }

  def run
    result = ActiveGraph::Base.query(QUERY).to_a.first
    count = result[:count]
    status = count == 0 ? :passed : :failed
    message = "#{count} circular relationship(s) found"

    DataIntegrityCheck::Result.new(status, message)
  end
end
