class DataIntegrityCheck::IncompatibleWithClade
  include DataIntegrityCheck::ZeroCountCheck

  private
  def query
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:object_term]->(object_term:Term)-[:incompatible_with_clade]->(clade:Page)
      WHERE (page)-[:parent*0..]->(clade)
      RETURN count(distinct trait) AS count
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} trait(s) with incompatible_with_clade object_terms where the trait's page is a member of the incompatible clade"
  end
end

