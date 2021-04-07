class DataIntegrityCheck::ExclusiveToClade
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  private
  def query
    <<~CYPHER
      #{query_common}
      RETURN count(distinct trait) AS count
    CYPHER
  end

  def detailed_report_query
    <<~CYPHER
      #{query_common}
      RETURN distinct page.page_id, trait.eol_pk, predicate.uri, clade.page_id
    CYPHER
  end

  def query_common
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:predicate]->(predicate:Term)-[:exclusive_to_clade]->(clade:Page)
      WHERE NOT (page)-[:parent*0..]->(clade)
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} trait(s) with exclusive_to_clade predicates where the trait's page is not a member of the required clade."
  end
end

