class TraitBank
  class Terms
    class << self
      delegate :connection, to: TraitBank
      delegate :query, to: TraitBank
      delegate :limit_and_skip_clause, to: TraitBank

      def count
        Rails.cache.fetch("trait_bank/terms_count", expires_in: 1.day) do
          res = query(
            "MATCH (term:Term { is_hidden_from_glossary: false }) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count")
          res && res["data"] ? res["data"].first.first : false
        end
      end

      def full_glossary(page = 1, per = nil)
        page ||= 1
        per ||= Rails.configuration.data_glossary_page_size
        Rails.cache.fetch("trait_bank/full_glossary/#{page}", expires_in: 1.day) do
          # "RETURN term ORDER BY term.name, term.uri"
          q = "MATCH (term:Term { is_hidden_from_glossary: false }) "\
            "RETURN DISTINCT(term) ORDER BY LOWER(term.name), LOWER(term.uri)"
          q += limit_and_skip_clause(page, per)
          res = query(q)
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : false
        end
      end

      def sub_glossary(type, page = 1, per = nil, options = {})
        count = options[:count]
        simple = options[:simple]
        page ||= 1
        per ||= Rails.configuration.data_glossary_page_size
        key = "trait_bank/#{type}_glossary/"\
          "#{count ? :count : "#{page}/#{per}"}/#{simple ? :simple : :full}"
        Rails.logger.info("KK TraitBank key: #{key}")
        Rails.cache.fetch(key, expires_in: 1.day) do
          q = "MATCH (term:Term"
          q += " { is_hidden_from_glossary: false }" unless simple
          q += ")<-[:#{type}]-(n) "
          if count
            q += "WITH COUNT(DISTINCT(term.uri)) AS count RETURN count"
          else
            q += "RETURN DISTINCT(term) ORDER BY LOWER(term.name), LOWER(term.uri)"
            q += limit_and_skip_clause(page, per)
          end
          res = query(q)
          if res["data"]
            if count
              res["data"].first.first
            else
              all = res["data"].map { |t| t.first["data"].symbolize_keys }
              all.map! { |h| { name: h[:name], uri: h[:uri] } } if simple
              all
            end
          else
            false
          end
        end
      end

      def predicate_glossary(page = nil, per = nil, simple = nil)
        sub_glossary("predicate", page, per, simple: simple)
      end

      def object_term_glossary(page = nil, per = nil, simple = nil)
        sub_glossary("object_term", page, per, simple: simple)
      end

      def units_glossary(page = nil, per = nil, simple = nil)
        sub_glossary("units_term", page, per, simple: simple)
      end

      def predicate_glossary_count
        sub_glossary("predicate", nil, nil, count: true)
      end

      def object_term_glossary_count
        sub_glossary("object_term", nil, nil, count: true)
      end

      def units_glossary_count
        sub_glossary("units_term", nil, nil, count: true)
      end

      # NOTE: I removed the units from this query after ea27411f8110b74 (q.v.)
      def page_glossary(page_id)
        q = "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait) "\
          "MATCH (trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "RETURN predicate, object_term"
        res = query(q)
        uris = {}
        res["data"].each do |row|
          row.each do |col|
            uris[col["data"]["uri"]] ||= col["data"].symbolize_keys if
              col && col["data"] && col["data"]["uri"]
          end
        end
        uris
      end
    end
  end
end
