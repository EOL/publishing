# checks for Terms with the same name that are not direct synonyms of each other
class DataIntegrityCheck::SameNameNotSynonym
  include DataIntegrityCheck::ZeroCountCheck  

  private
  def query
    %{
      MATCH (t1:Term), (t2:Term)
      WHERE t1 <> t2 aND t1.name = t2.name AND NOT (t1)-[:synonym_of]->(t2) AND NOT (t2)-[:synonym_of]->(t1)
      AND NOT (t2)-[:synonym_of]->(:Term)<-[:synonym_of]-(t1)
      WITH DISTINCT t1, t2
      RETURN count(*) / 2 AS count
    }
  end

  def build_count_message(count)
    "Found #{count} pair(s) of terms with the same name that aren't direct synonyms of each other."
  end
end
