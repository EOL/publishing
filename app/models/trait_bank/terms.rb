class TraitBank
  class Terms
    class << self
      delegate :connection, to: TraitBank
      delegate :limit_and_skip_clause, to: TraitBank
      delegate :query, to: TraitBank
      delegate :child_has_parent, to: TraitBank
      delegate :is_synonym_of, to: TraitBank
      delegate :array_to_qs, to: TraitBank

      CACHE_EXPIRATION_TIME = 1.week # We'll have a post-import job refresh this as needed, too.
      TERM_TYPES = {
        predicate: ['measurement', 'association'],
        object_term: ['value']
      }

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
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : false
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
        per ||= Rails.configuration.data_glossary_page_size
        key = "trait_bank/#{type}_glossary/#{count ? :count : "#{page}/#{per}"}/"\
          "for_select_#{for_select ? 1 : 0}/#{qterm ? qterm : :full}"
        Rails.logger.info("KK TraitBank key: #{key}")
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = 'MATCH (term:Term'
          # NOTE: UUUUUUGGGGGGH.  This is suuuuuuuper-ugly. Alas... we don't have a nice query-builder.
          q += ' { is_hidden_from_glossary: false }' unless qterm
          q += ')'
          q += "<-[:#{type}]-(n) " if type == 'units_term'
          q += " WHERE " if qterm || TERM_TYPES.key?(type)
          q += "LOWER(term.name) =~ \"#{qterm.gsub(/"/, '').downcase}.*\" " if qterm
          q += " AND " if qterm && TERM_TYPES.key?(type)
          q += %{term.type IN ["#{TERM_TYPES[type].join('","')}"]} if TERM_TYPES.key?(type)
          if for_select
            q += qterm ? " AND" : " WHERE"
            q += " term.is_hidden_from_select = false "
          end
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

      def top_level(type)
        types = TERM_TYPES[type]
        raise TypeError.new("invalid type argument") if types.nil?

        q = "MATCH (term:Term) "\
            "WHERE NOT (term)-[:parent_term]->(:Term) "\
            "AND NOT (term)-[:synonym_of]->(:Term) "\
            "AND term.is_hidden_from_overview = false "\
            "AND term.type IN #{array_to_qs(types)} "\
            "RETURN term "\
            "ORDER BY lower(term.name), term.uri"

        term_query(q)
      end

      def children(uri)
        q = "MATCH (term:Term)-[:parent_term]->(:Term{ uri:'#{uri}' }) "\
            "WHERE NOT (term)-[:synonym_of]->(:Term) "\
            "RETURN term "\
            "ORDER BY lower(term.name), term.uri"
        term_query(q)
      end

      def term_query(q)
        res = query(q)
        all = res["data"].map { |t| t.first["data"].symbolize_keys }
        all.map! { |h| { name: h[:name], uri: h[:uri] } }
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
          q += "WHERE LOWER(object.name) =~ \"#{qterm}.*\" " if qterm
          q +=  'RETURN object ORDER BY object.position LIMIT 6'
          res = query(q)
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : []
        end
      end

      def any_obj_terms_for_pred?(pred)
        Rails.cache.fetch("trait_bank/pred_has_object_terms_2_checks/#{pred}", expires_in: CACHE_EXPIRATION_TIME) do
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)<-[:synonym_of|:parent_term*0..]-(:Term { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any? ||
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)-[:synonym_of|:parent_term*0..]->(:Term { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any?
        end
      end

      # NOTE the order of args, here.
      def set_units_for_pred(units_uri, pred_uri)
        if units_uri =~ /^u/ # 'unitless', a secret code for "this is an ordinal measurement (and has no units)"
          query(%{MATCH (predicate:Term { uri: "#{pred_uri}" }) SET predicate.is_ordinal = true})
        else
          query(%{MATCH (predicate:Term { uri: "#{pred_uri}" }), (units_term:Term { uri: "#{units_uri}"})
            CREATE (predicate)-[:units_term]->(units_term)})
        end
      end

      def units_for_pred(pred_uri)
        key = "trait_bank/normal_unit_for_pred/#{pred_uri}"

        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          ordinal = query(%{
            MATCH (predicate:Term { uri: "#{pred_uri}", is_ordinal: true }) RETURN predicate LIMIT 1
          })["data"].any?
          if ordinal
            :ordinal
          else
            res = query(%{
              MATCH (predicate:Term { uri: "#{pred_uri}" })-[:units_term]->(units_term:Term)
              RETURN units_term.name, units_term.uri LIMIT 1
            })["data"]
            if (result = res&.first)
              (name, uri) = result
              { units_name: name, units_uri: uri, normal_units_name: name, normal_units_uri: uri }
            else
              nil
            end
          end
        end
      end

      def warm_caches
        pages_to_filter_by_predicate = read_clade_filter_warmers
        page = 1
        loop do
          gloss = predicate_glossary(page)
          break if gloss.empty?
          gloss.each do |term|
            q = TermQuery.new(filters_attributes: [{pred_uri: term[:uri], op: 'is_any' }])
            # NOTE: it's probably important that the per-page is the same as in the search_controller:
            TraitBank.term_search(q, page: 1, per: 50)
            ('a'..'z').each { |letter| obj_terms_for_pred(term[:uri], letter) }
            if pages_to_filter_by_predicate.key?(term[:uri])
              pages_to_filter_by_predicate[term[:uri]].each do |clade_id|
                q = TermQuery.new(filters_attributes: [{pred_uri: term[:uri], op: 'is_any' }], clade_id: clade_id)
                TraitBank.term_search(q, page: 1, per: 50)
              end
            end
            sleep(0.25) # Give it a *little* rest. Heh.
          end
          page += 1
          raise "Whoa! Huge predicate glossary, aborting." if page > 10
        end
      end

      def read_clade_filter_warmers
        return nil unless Resource.exists?(id: 1)
        require 'csv'
        pks_to_filter_by_predicate = {}
        pages_to_filter_by_predicate = {}
        pks = {}
        clade_filter_warmer_csv = Rails.root.join('doc', "clade_filter_warmers.csv")
        CSV.read(clade_filter_warmer_csv).each do |line|
          predicate = line[1]
          pk = line[0]
          pks_to_filter_by_predicate[predicate] ||= []
          pks_to_filter_by_predicate[predicate] << pk
          pks[pk] ||= true
        end
        # NOTE: This is actually a pretty OLD list, but updating it is time-consuming, so we're sticking with it:
        pairs = Node.where(resource_id: 1, resource_pk: pks.keys).pluck('resource_pk, page_id')
        page_id_by_pk = {}
        pairs.each { |pair| page_id_by_pk[pair.first] = pair.last }
        pks_to_filter_by_predicate.each do |predicate, pks|
          pks.each do |pk|
            unless page_id_by_pk.key?(pk)
              puts "** WARNING: Missing PK #{pk} in Dynamic Hierarchy. Skipping."
              next
            end
            pages_to_filter_by_predicate[predicate] ||= []
            pages_to_filter_by_predicate[predicate] << page_id_by_pk[pk]
          end
        end
        pages_to_filter_by_predicate
      end
    end
  end
end
