# q.v.:
class TraitBank
  # "Glossary" and meta-data methods about terms (plural) stored in TraitBank. See TraitBank::Term for methods handling a
  # single "instance."
  class Terms
    CACHE_EXPIRATION_TIME = 1.week # We'll have a post-import job refresh this as needed, too.
    TERM_TYPES = {
      predicate: ['measurement', 'association'],
      object_term: ['value']
    }.freeze
    DEFAULT_GLOSSARY_PAGE_SIZE = Rails.configuration.data_glossary_page_size

    class << self
      delegate :query, :connection, :limit_and_skip_clause, :array_to_qs, to: TraitBank
      delegate :child_has_parent, :is_synonym_of, to: TraitBank::Term # TODO: TraitBank::Term::Relationship
      delegate :log, to: TraitBank::Logger

      def count(options = {})
        hidden = options[:include_hidden]
        key = "trait_bank/terms_count"
        key += "/include_hidden" if hidden
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = query(
            "MATCH (term:Term#{hidden ? '' : ' { is_hidden_from_glossary: false }'}) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count"
          )
          res && res["data"] ? res["data"].first.first : false
        end
      end

      def full_glossary(page = 1, per = nil, options = {})
        options ||= {} # callers may pass nil, bypassing the default
        page ||= 1
        per ||= Rails.configuration.data_glossary_page_size
        hidden = options[:include_hidden]
        key = "trait_bank/full_glossary/#{page}"
        key += "/include_hidden" if hidden
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (term:Term#{hidden ? '' : ' { is_hidden_from_glossary: false }'}) "\
            "RETURN DISTINCT(term) ORDER BY LOWER(term.name), LOWER(term.uri)"
          q += limit_and_skip_clause(page, per)
          res = query(q)
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : false
        end
      end

      # XXX: "0-9" is considered a letter, and gets all terms that start with a digit. Everything else is an actual letter.
      def glossary_for_letter(letter, options = {})
        raise "invalid letter argument" if !letters_for_glossary.include?(letter)

        key = "trait_bank/glossary_for_letter/#{letter}"
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          where = if letter == "0-9"
                    "term.name =~ '[0-9].*'"
                  else
                    "substring(toLower(term.name), 0, 1) = '#{letter}'"
                  end

          q = "MATCH (term:Term{ is_hidden_from_glossary: false }) "\
              "WHERE #{where} "\
              "RETURN term "\
              "ORDER BY toLower(term.name), toLower(term.uri)"
          res = query(q)
          res["data"] ? res["data"].map { |t| t.first.symbolize_keys } : false
        end
      end

      def letters_for_glossary
        Rails.cache.fetch("trait_bank/letters_for_glossary", expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (term:Term{ is_hidden_from_glossary: false })\n"\
              "WITH CASE\n"\
              "WHEN term.name =~ '[0-9].*' THEN '0-9'\n"\
              "ELSE substring(toLower(term.name), 0, 1) END AS letter\n"\
              "RETURN DISTINCT letter\n"\
              "ORDER BY letter"
          res = query(q)
          res["data"] ? res["data"].map { |item| item.first } : false
        end
      end

      def letter_for_term(term)
        if term[:name] =~ /[0-9].*/
          return "0-9"
        else
          return term[:name].downcase[0]
        end
      end

      def sub_glossary(type, page = 1, per = nil, options = {})
        count = options[:count]
        qterm = options[:qterm]
        for_select = options[:for_select]
        page ||= 1
        per ||= DEFAULT_GLOSSARY_PAGE_SIZE
        key = "trait_bank/#{type}_glossary/#{I18n.locale}/#{count ? :count : "#{page}/#{per}"}/"\
          "for_select_#{for_select ? 1 : 0}/#{qterm ? qterm : :full}"
        log("KK TraitBank key: #{key}")
        name_field = Util::I18nUtil.term_name_property
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = 'MATCH (term:Term'
          # NOTE: UUUUUUGGGGGGH.  This is suuuuuuuper-ugly. Alas... we don't have a nice query-builder.
          q += ' { is_hidden_from_glossary: false }' unless qterm
          q += ')'
          q += "<-[:#{type}]-(n) " if type == 'units_term'
          q += " WHERE " if qterm || TERM_TYPES.key?(type)
          q +=  term_name_prefix_match("term", qterm) if qterm
          q += " AND " if qterm && TERM_TYPES.key?(type)
          q += %{term.type IN ["#{TERM_TYPES[type].join('","')}"]} if TERM_TYPES.key?(type)
          if for_select
            q += qterm ? " AND" : " WHERE"
            q += " term.is_hidden_from_select = false "
          end
          if count
            q += "WITH COUNT(DISTINCT(term.uri)) AS count RETURN count"
          else
            q += "RETURN DISTINCT(term) ORDER BY LOWER(term.#{name_field}), LOWER(term.uri)"
            q += limit_and_skip_clause(page, per)
          end
          res = query(q)
          if res["data"]
            if count
              res["data"].first.first
            else
              all = res["data"].map { |t| t.first["data"].symbolize_keys }
              all.map! { |h| { name: h[:"#{name_field}"], uri: h[:uri] } } if qterm
              all
            end
          else
            false
          end
        end
      end

      def top_level(type)
        types = TERM_TYPES[type]
        raise TypeError.new("invalid type argument") if types.nil?

        q = "MATCH (term:Term) "\
            "WHERE NOT (term)-[:parent_term]->(:Term) "\
            "AND NOT (term)-[:synonym_of]->(:Term) "\
            "AND term.is_hidden_from_overview = false "\
            "AND term.type IN #{array_to_qs(types)} "\
            "RETURN term "\
            "ORDER BY lower(term.#{Util::I18nUtil.term_name_property}), term.uri"

        term_query(q)
      end

      def children(uri)
        q = "MATCH (term:Term)-[:parent_term]->(:Term{ uri:'#{uri}' }) "\
            "WHERE NOT (term)-[:synonym_of]->(:Term) "\
            "RETURN term "\
            "ORDER BY lower(term.#{Util::I18nUtil.term_name_property}), term.uri"
        term_query(q)
      end

      def term_query(q)
        res = query(q)
        all = res["data"].map { |t| t.first["data"].symbolize_keys }
        all.map! { |h| { name: h[:"#{Util::I18nUtil.term_name_property}"], uri: h[:uri] } }
        all
      end

      def predicate_glossary(page = nil, per = nil, options = {})
        sub_glossary(:predicate, page, per, options)
      end

      def name_for_pred_uri(uri)
        key = "trait_bank/predicate_uris_to_names/#{uri}"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          predicate_glossary(1, 10_000).map { |item| [item[:uri], item[:name]] }.to_h
        end

        map[uri]
      end

      def name_for_uri(uri)
        return '' if uri.blank?
        Rails.cache.fetch("trait_bank/name_for_uri/#{uri}", :expires_in => CACHE_EXPIRATION_TIME) do
          res = TraitBank.term(uri)
          name =
            if res&.key?('data')
              if res['data']&.key?('name')
                res['data']['name']
              end
            end
          name || uri.split('/').last # Some of these end up gobbledigook, but ... hey.
        end
      end

      def name_for_obj_uri(uri)
        key = "trait_bank/name_for_obj_uri/#{uri}"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          object_term_glossary(1, 10_000).map { |item| [item[:uri], item[:name]] }.to_h
        end

        map[uri]
      end

      def name_for_units_uri(uri)
        key = "trait_bank/name_for_units_uri/#{uri}"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          units_glossary(1, 10_000).map { |item| [item[:uri], item[:name]] }.to_h
        end
        map[uri]
      end

      def object_term_glossary(page = nil, per = nil, options = {})
        sub_glossary(:object_term, page, per, options)
      end

      def units_glossary(page = nil, per = nil, options = {})
        sub_glossary(:units_term, page, per, options)
      end

      def predicate_glossary_count
        sub_glossary(:predicate, nil, nil, count: true)
      end

      def object_term_glossary_count
        sub_glossary(:object_term, nil, nil, count: true)
      end

      def units_glossary_count
        sub_glossary(:units_term, nil, nil, count: true)
      end

      # NOTE: I removed the units from this query after ea27411f8110b74 (q.v.)
      def page_glossary(page_id)
        q = "MATCH (page:Page { page_id: #{page_id} })-[#{TraitBank::TRAIT_RELS}]->(trait:Trait) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "RETURN predicate, object_term"
        res = query(q)
        uris = {}
        res["data"].each do |row|
          row.each do |col|
            uris[col["data"]["uri"]] ||= col["data"].symbolize_keys if col&.dig("data", "uri")
          end
        end
        uris
      end
    end
  end
end
