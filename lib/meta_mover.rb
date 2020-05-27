class MetaMover
  BATCH_SIZE = 10_000

  attr_reader :pred_uri, :old_attr_name, :new_attr_name

  def initialize(pred_uri, old_attr_name, new_attr_name)
    @pred_uri = pred_uri
    @old_attr_name = old_attr_name
    @new_attr_name = new_attr_name
  end

  def run
    count_q = %Q(
      MATCH (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(:Term{uri: '#{pred_uri}'})
      WHERE t.#{new_attr_name} IS NULL AND m.#{old_attr_name} IS NOT NULL
      WITH DISTINCT t, m
      RETURN count(*)
    )

    q = %Q(
      MATCH (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(:Term{uri: '#{pred_uri}'})
      WHERE t.#{new_attr_name} IS NULL AND m.#{old_attr_name} IS NOT NULL
      WITH DISTINCT t, m
      LIMIT #{BATCH_SIZE}
      SET t.#{new_attr_name} = m.#{old_attr_name}
      RETURN count(*)
    )

    total_count = 1
    while total_count > 0 
      puts "query: #{q}"
      result = TraitBank.query(q)
      count = result["data"][0][0]
      puts "copied #{count} records"
      count_result = TraitBank.query(count_q)
      total_count = count_result["data"][0][0]
      puts "#{total_count} records remaining"
    end

    puts "finished copying metadata"
    delete_metas
  end

  def delete_metas
    puts "deleting metadata"
    TraitBank::Admin.remove_with_query(
      name: :m,
      q: "(m:MetaData)-[:predicate]->(:Term{uri: '#{pred_uri}'}) WHERE m.#{old_attr_name} IS NOT NULL"
    )
  end 

  class << self
    def run_all
      movers = [
        self.new("http://eol.org/schema/terms/SampleSize", "measurement", "sample_size"),
        self.new("http://purl.org/dc/terms/bibliographicCitation", "literal", "citation"),
        self.new("http://purl.org/dc/terms/source", "literal", "source"),
        self.new("http://rs.tdwg.org/dwc/terms/measurementRemarks", "literal", "remarks"),
        self.new("http://rs.tdwg.org/dwc/terms/measurementMethod", "literal", "method")
      ]

      movers.each do |m|
        puts "running MetaMover"
        puts "predicate: #{m.pred_uri}"
        puts "meta attribute name: #{m.old_attr_name}"
        puts "new trait attribute name: #{m.new_attr_name}"
        m.run
        puts "---------------------------------------"
      end
    end
  end

  private
  def limit_and_skip(batch)
    %Q(
      SKIP #{batch * BATCH_SIZE}
      LIMIT #{BATCH_SIZE}
    )
  end
end

