module DataIntegrityCheck::HasPairUriDetailedReport
  def detailed_report
    query = <<~CYPHER
      #{query_common}
      RETURN t1.uri AS uri1, t2.uri AS uri2
    CYPHER

    result = ActiveGraph::Base.query(query).to_a
    display_result = result.map do |r|
      '[' + [r[:uri1], r[:uri2]].join(', ') + ']'
    end.join("\n")

    <<~END
      Query:
      #{query}
      
      Result:
      #{display_result}
    END
  end
end
