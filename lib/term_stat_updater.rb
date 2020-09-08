class TermStatUpdater
  BATCH_SIZE = 1000

  class << self
    def run
      [:predicate, :object_term].each do |term_type|
        page = 0
        uris = []

        while page == 0 || uris.any?
          puts "Fetching page #{page} (x #{BATCH_SIZE}) of #{term_type} uris"
          uris = fetch_uri_batch(page, term_type)

          uris.each do |uri|
            update_term_counts(uri, term_type)
          end

          page += 1
        end
      end
    end 

    def fetch_uri_batch(page, term_type)
      q = %Q(
        MATCH (t:Term) 
        WHERE t.type IN #{TraitBank::Glossary::TERM_TYPES[term_type]}
        RETURN t.uri
        ORDER BY t.uri
        SKIP #{page * BATCH_SIZE}
        LIMIT #{BATCH_SIZE}
      )
      res = TraitBank.query(q)
      res["data"].flatten
    end

    def update_term_counts(uri, term_type)
      puts "Updating trait row counts for #{uri}"
      trait_row_q = %Q(
        MATCH (term:Term{ uri: "#{uri}" }),
        (trait:Trait)-[:#{term_type}]->(:Term)-[#{TraitBank.parent_terms}]->(term)
        WITH term, count(*) as trait_row_count
        SET term.trait_row_count = trait_row_count
      )
      TraitBank.query(trait_row_q)

      puts "Updating distinct page counts for #{uri}"
      distinct_page_q = %Q(
        MATCH (term:Term{ uri: "#{uri}" }),
        (trait:Trait)-[:#{term_type}]->(:Term)-[#{TraitBank.parent_terms}]->(term),
        (page:Page)-[:trait|:inferred_trait]->(trait)
        WITH term, count(distinct page) as distinct_page_count
        SET term.distinct_page_count = distinct_page_count
      )
      TraitBank.query(distinct_page_q)
    end
  end 
end

