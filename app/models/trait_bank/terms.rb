class TraitBank
  class Terms
    class << self
      delegate :connection, to: TraitBank
      delegate :limit_and_skip_clause, to: TraitBank
      delegate :query, to: TraitBank

      CACHE_EXPIRATION_TIME = 1.week # We'll have a post-import job refresh this as needed, too.

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

      def sub_glossary(type, page = 1, per = nil, options = {})
        count = options[:count]
        qterm = options[:qterm]
        page ||= 1
        per ||= Rails.configuration.data_glossary_page_size
        key = "trait_bank/#{type}_glossary/"\
          "#{count ? :count : "#{page}/#{per}"}/#{qterm ? qterm : :full}"
        Rails.logger.info("KK TraitBank key: #{key}")
        types = {
          'predicate' => 'measurement',
          'object_term' => 'value'
        }
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = 'MATCH (term:Term'
          # NOTE: UUUUUUGGGGGGH.  This is super-ugly. Alas... we don't have a nice query-builder.
          q += ' {' if !qterm || types.key?(type)
          q += ' is_hidden_from_glossary: false' unless qterm
          q += ',' if !qterm && types.key?(type)
          q += " type: \"#{types[type]}\"" if types.key?(type)
          q += ' }' if !qterm || types.key?(type)
          q += ')'
          q += "<-[:#{type}]-(n) " if type == 'units_term'
          q += " WHERE LOWER(term.name) CONTAINS \"#{qterm.gsub(/"/, '').downcase}\" " if qterm
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
              all.map! { |h| { name: h[:name], uri: h[:uri] } } if qterm
              all
            end
          else
            false
          end
        end
      end

      def predicate_glossary(page = nil, per = nil, qterm = nil)
        sub_glossary("predicate", page, per, qterm: qterm)
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
            if res.key?('data')
              if res['data'].key?('name')
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

      def object_term_glossary(page = nil, per = nil, qterm = nil)
        sub_glossary('object_term', page, per, qterm: qterm)
      end

      def units_glossary(page = nil, per = nil, qterm = nil)
        sub_glossary('units_term', page, per, qterm: qterm)
      end

      def predicate_glossary_count
        sub_glossary('predicate', nil, nil, count: true)
      end

      def object_term_glossary_count
        sub_glossary('object_term', nil, nil, count: true)
      end

      def units_glossary_count
        sub_glossary("units_term", nil, nil, count: true)
      end

      # NOTE: I removed the units from this query after ea27411f8110b74 (q.v.)
      def page_glossary(page_id)
        q = "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
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

      # TEMP: We're no longer checking this against the passed-in pred_uri. Sorry. Keeping the interface for it, though,
      # since we will want it back. :) You'll have to look at an older version (e.g.: aaf4ba91e7 ) to see the changes; I
      # kept them around as comments for one version, but it was really hairy, so I removed it.
      def obj_terms_for_pred(_, orig_qterm = nil)
        return [] if orig_qterm.blank?
        qterm = orig_qterm.delete('"').downcase
        Rails.cache.fetch("trait_bank/obj_terms_for_pred/#{qterm}", expires_in: CACHE_EXPIRATION_TIME) do
          q = 'MATCH (object:Term { type: "value", is_hidden_from_select: false }) '
          q += "WHERE LOWER(object.name) CONTAINS \"#{qterm}\" " if qterm
          q +=  'RETURN object ORDER BY object.position LIMIT 6'
          res = query(q)
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : []
        end
      end

      def any_obj_terms_for_pred?(pred)
        Rails.cache.fetch("trait_bank/any_obj_terms_for_pred/#{pred}", expires_in: CACHE_EXPIRATION_TIME) do
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term { uri: '#{pred}'}) RETURN term LIMIT 1}
          )["data"].any?
        end
      end

      def units_for_pred(pred_uri)
        key = "trait_bank/normal_unit_for_pred/#{pred_uri}"

        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = query(
            "MATCH (predicate:Term { uri: \"#{pred_uri}\" })-[:units_term]->(units_term:Term) "\
            'RETURN units_term.name, units_term.uri LIMIT 1'
          )

          result = res["data"]&.first || nil

          result = {
            :units_name => result[0],
            :units_uri => result[1],
            :normal_units_name => result[2],
            :normal_units_uri => result[3]
          } if result

          result
        end
      end

      def warm_caches
        page = 1
        loop do
          gloss = predicate_glossary(page)
          break if gloss.empty?
          gloss.each do |term|
            # YOU WERE HERE.
          end
          raise "Whoa! Huge predicate glossary, aborting." if page > 200
        end
      end
    end
  end
end
