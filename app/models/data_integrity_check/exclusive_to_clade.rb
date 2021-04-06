class DataIntegrityCheck::ExclusiveToClade
  include DataIntegrityCheck::ZeroCountCheck

  private
  def query
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:predicate]->(predicate:Term)-[:exclusive_to_clade]->(clade:Page)
      WHERE NOT (page)-[:parent*0..]->(clade)
      RETURN count(distinct trait) AS count
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} trait(s) with exclusive_to_clade predicates where the trait's page is not a member of the required clade."
  end
end

