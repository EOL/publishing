class DataIntegrityCheck::IncompatibleWithClade
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
      RETURN page.page_id, trait.eol_pk, object_term.uri, clade.page_id
    CYPHER
  end

  def query_common
    <<~CYPHER
      MATCH (page:Page)-[:trait]->(trait:Trait),
      (trait)-[:object_term]->(object_term:Term)-[:incompatible_with_clade]->(clade:Page)
      WHERE (page)-[:parent*0..]->(clade)
    CYPHER
  end


  def build_count_message(count)
    "Found #{count} trait(s) with incompatible_with_clade object_terms where the trait's page is a member of the incompatible clade"
  end
end

