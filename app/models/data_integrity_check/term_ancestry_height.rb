class DataIntegrityCheck::TermAncestryHeight
  def run
    query = %{
      MATCH p = (t1:Term)-[:parent_term|synonym_of*1..]->(t2:Term)
      WHERE t1 <> t2
      WITH t1, t2, min(length(p)) AS min_length
      RETURN max(min_length) AS height
    }

    height = ActiveGraph::Base.query(query).to_a.first[:height]

    DataIntegrityCheck::Result.new(
      :passed, 
      "The height of the Term ancestry (max shortest path from an ancestor to a descendant) is #{height}. This test always passes."
    )
  end
end
