class ObjectPageMover
  class << self
    def run
      create_rels
      count_missed_rels
    end

    def create_rels
      batch = 0
      limit = 1000
      count = 0

      puts "creating missing relationships"

      while batch == 0 || count > 0
        puts "batch # #{batch} (of #{limit})"
        q = %Q(
          MATCH (t:Trait), (p:Page)
          WHERE t.object_page_id IS NOT NULL AND p.page_id = t.object_page_id AND NOT (t)-[:object_page]->()
          WITH t, p
          LIMIT #{limit}
          CREATE (t)-[:object_page]->(p)
          RETURN count(*)
        )

        result = TraitBank.query(q)
        count = result["data"].first.first
        batch += 1
      end

      puts "done creating relationships"
    end

    def count_missed_rels
      puts "Checking for unmatched object_page_id traits"

      q = %q(
        MATCH (t:Trait) WHERE t.object_page_id IS NOT NULL AND NOT (t)-[:object_page]->()
        RETURN count(t), count(distinct t.object_page_id)
      )

      result = TraitBank.query(q)
      puts "There are #{result["data"].first.first} traits with #{result["data"].first.second} unmatched object_page_ids"
    end
  end
end
