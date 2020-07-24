class MetaMover2
  attr_reader :meta_pred_uri, :new_rel_name

  def initialize(meta_pred_uri, new_rel_name)
    @meta_pred_uri = meta_pred_uri
    @new_rel_name = new_rel_name
  end

  def run
    create_rels
  end

  def create_rels
    rels_created = 1
    total_rels_created = 0
    limit = 10_000

    while rels_created > 0
      query = %Q(
        MATCH (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(:Term{uri: "#{meta_pred_uri}" }),
        (m)-[:object_term]->(obj:Term)
        WHERE NOT (t)-[:#{new_rel_name}]->()
        WITH t, collect(obj)[0] AS obj
        LIMIT #{limit}
        CREATE (t)-[r:#{new_rel_name}]->(obj)
        RETURN count(r)
      )
      puts "Query: #{query}"
      response = TraitBank.query(query)
      puts "Response: #{response}"
      rels_created = response["data"].first.first
      total_rels_created += rels_created
    end

    puts "Done. Created #{total_rels_created} relationships."
  end

  def delete_old_metas
    query = %Q(
      (t:Trait)-[:metadata]->(m:MetaData)-[:predicate]->(:Term{uri: "#{meta_pred_uri}"}),
      (t)-[:#{new_rel_name}]->(:Term)
    )
    puts "Deleting old metadata:\n#{query}"
    TraitBank::Admin.remove_with_query(
      name: :m,
      q: query
    )
    puts "Done."
  end

  class << self
    def movers
      @movers ||= [
        self.new("http://eol.org/schema/terms/statisticalMethod", "statistical_method_term"),
        self.new("http://rs.tdwg.org/dwc/terms/sex", "sex_term"),
        self.new("http://rs.tdwg.org/dwc/terms/lifeStage", "lifestage_term"),
        self.new("http://rs.tdwg.org/dwc/terms/measurementUnit", "units_term")
      ]
    end

    def create_rels
      movers.each { |m| m.run }
    end

    def delete_old_metas
      movers.each { |m| m.delete_old_metas }
    end
  end
end

