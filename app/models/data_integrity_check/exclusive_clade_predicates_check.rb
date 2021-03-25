class DataIntegrityCheck::ExclusiveCladePredicatesCheck
  include DataIntegrityCheck::ZeroCountCheck
  include DataIntegrityCheck::HasDetailedReport

  private
  def query
    <<~CYPHER
      MATCH (page:Page)-[:trait|inferred_trait]->(trait:Trait), 
      (trait)-[:predicate]->(pred:Term), 
      (pred)-[:exclusive_to_clade]->(clade:Page)
      WHERE NOT (page)-[:parent*0..]->(clade)
      RETURN count(*) AS count
    CYPHER
  end

  def build_count_message(count)
    "Found #{count} (page:Page)-[:trait|inferred_trait]->(trait:Trait) rows where the trait has an exclusive_to_clade predicate and the page is not a member of the expected clade."
  end

  def detailed_report_query
    <<~CYPHER
      MATCH (page:Page)-[:trait|inferred_trait]->(trait:Trait), 
      (trait)-[:predicate]->(pred:Term), 
      (pred)-[:exclusive_to_clade]->(clade:Page)
      WHERE NOT (page)-[:parent*0..]->(clade)
      RETURN page.page_id, trait.eol_pk, pred.uri
    CYPHER
  end
end
