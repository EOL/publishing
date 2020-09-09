# q.v.:
class TraitBank
  # Handles all of the methods specific to a :Term node.
  module Term
    class << self
      RELATIONSHIP_PROPERTIES = { 'parent_uris' => 'parent', 'synonym_of_uri' => 'synonym_of'}.freeze
      BOOLEAN_PROPERTIES =
        %w[is_text_only is_hidden_from_select is_hidden_from_overview is_hidden_from_glossary is_verbatim_only].freeze
      CACHE_EXPIRATION_TIME = 1.week # We'll have a post-import job refresh this as needed, too.
      TERM_TYPES = {
        predicate: ['measurement', 'association'],
        object_term: ['value']
      }.freeze
      DEFAULT_GLOSSARY_PAGE_SIZE = Rails.configuration.data_glossary_page_size

      delegate :query, :connection, :limit_and_skip_clause, :array_to_qs, to: TraitBank
      delegate :child_has_parent, :is_synonym_of, to: TraitBank::Term # TODO: TraitBank::Term::Relationship
      delegate :log, to: TraitBank::Logger

      # This method will detect existing Terms and either return the existing term or, if the :force option is set, update the
      # Term instead.
      def create(properties)
        properties = properties.transform_keys(&:to_s)
        raise 'Cannot create a term without a URI' unless properties['uri']
        existing_term = term(properties['uri'])
        return existing_term if existing_term && !properties.delete(:force)

        clean_properties(properties)
        return update_existing(existing_term, properties) if existing_term

        create_new(properties)
      end

      # This method assumes you have an existing term object that you pulled from neo4j. Use #update if you just have a hash.
      def update_existing(existing_term, properties)
        uri = properties.delete('uri') # We already have this.
        begin
          update_relationships(uri, properties)
          connection.set_node_properties(existing_term, properties)
        rescue => e # rubocop:disable Style/RescueStandardError
          # This method is typically run as part of a script, so I'm just using STDOUT here:
          puts "ERROR: failed to update term #{properties['uri']}"
          puts "EXISTING: #{existing_term.inspect}"
          puts "DESIRED: #{properties.inspect}"
          puts "You will need to fix this manually. Make note!"
        end
        existing_term
      end

      # This method takes a hash as its argument. If you pulled a term from neo4j, use #update_existing
      # This method will only update fields that are passed in. Other fields will keep their existing values.
      # On success, this always returns a hash with *symbolized* keys.
      def update(properties)
        properties = properties.transform_keys(&:to_s)
        raise 'Cannot update a term without a URI.' unless properties['uri']
        clean_properties(properties)
        update_relationships(properties['uri'], properties)
        res = query(query_for_update(properties))
        raise ActiveRecord::RecordNotFound if res.nil?
        res['data'].first.first.symbolize_keys
      end

      def update_relationships(uri, properties)
        RELATIONSHIP_PROPERTIES.each do |property, name|
          if target_uris = properties.delete(property)
            remove_relationships(uri, name)
            Array(target_uris).each do |target_uri|
              add_relationship(uri, name, target_uri)
            end
          end
        end
      end

      def remove_relationships(uri, name)
        TraitBank.query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '""')}"})-[rel:#{name}]->() DETACH DELETE rel})
      end

      def add_relationship(source_uri, name, target_uri)
        TraitBank.query(%{CREATE (term:Term { uri: "#{source_uri.gsub(/"/, '""')}" })-[:#{name}]->(target:Term
                          { uri: "#{target_uri.gsub(/"/, '""')}}"})
      end

      def query_for_update(properties)
        sets = []
        properties.each do |property|
          if BOOLEAN_PROPERTIES.include?(property) # Booleans are handled separately.
            sets << "term.#{field} = #{properties[field] ? 'true' : 'false'}"
          elsif RELATIONSHIP_PROPERTIES.keys.include?(property)
            # we have to skip that here; reltionships must be done with a separate query. (Should already have been called.)
          else
            sets << "term.#{property} = '#{properties[property].gsub("'", "''")}'"
          end
        end
        "MATCH (term:Term { uri: '#{properties['uri']}' }) SET #{sets.join(', ')} RETURN term"
      end

      def clean_properties(properties)
        properties.delete('section_ids') # Vestigial, do not allow anymore.
        properties['definition'] ||= "{definition missing}"
        properties['definition'].gsub!(/\^(\d+)/, "<sup>\\1</sup>")
        set_boolean_properties(properties)
        set_nil_properties_to_blank(properties)
      end

      def set_boolean_properties(properties)
        BOOLEAN_PROPERTIES.each do |key|
          properties[key] = treat_property_as_true?(properties, key) ? true : false
        end
      end

      def treat_property_as_true?(properties, key)
        properties.key?(key) && properties[key] && !properties[key].to_s.downcase == 'false'
      end

      def remove_relationship_properties(properties)
        removed = {}
        RELATIONSHIP_PROPERTIES.keys.each do |property|
          removed[property] = properties.delete(property) if properties.key?(property)
        end
        removed
      end

      def create_new(properties)
        removed = remove_relationship_properties(properties)
        term_node = connection.create_node(properties)
        # ^ I got a "Could not set property "uri", class Neography::PropertyValueException here.
        connection.set_label(term_node, 'Term')
        # ^ I got a Neography::BadInputException here saying I couldn't add a label. In that case, the URI included
        # UTF-8 chars, so I think I fixed it by causing all URIs to be escaped...
        update_relationships(properties['uri'], removed) unless removed.blank?
        increment_terms_count_cache
        term_node
      end

      def increment_terms_count_cache
        count = Rails.cache.read('trait_bank/terms_count') || 0
        Rails.cache.write('trait_bank/terms_count', count + 1)
      end

      def set_nil_properties_to_blank(hash)
        bad_keys = [] # Never modify a hash as you iterate over it.
        hash.each { |key, val| bad_keys << key if val.nil? }
        # NOTE: removing the key entirely would just skip updating it; we want the value to be empty.
        bad_keys.each { |key| hash[key] = '' }
        hash
      end

      def delete(uri)
        # Not going to bother with DETACH, since there should only be one!
        TraitBank.query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '""')}"}) DELETE term})
      end

      # TODO: I think we need a TraitBank::Term::Relationship class with these in it! Argh!

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def child_has_parent(curi, puri)
        cterm = term(curi)
        pterm = term(puri)
        raise "missing child" if cterm.nil?
        raise "missing parent" if pterm.nil?
        child_term_has_parent_term(cterm, pterm)
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def is_synonym_of(curi, puri)
        cterm = term(curi)
        pterm = term(puri)
        raise "missing synonym" if cterm.nil?
        raise "missing source of synonym" if pterm.nil?
        relate(:synonym_of, cterm, pterm)
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def child_term_has_parent_term(cterm, pterm)
        relate(:parent_term, cterm, pterm)
      end

      def term_as_hash(uri)
        return nil if uri.nil? # Important for param-management!
        hash = term(uri)
        raise ActiveRecord::RecordNotFound if hash.nil?
        hash.symbolize_keys
      end

      # Raises ActiveRecord::RecordNotFound if uri is invalid
      def term_record(uri)
        result = term(uri)
        result&.[]("data")&.symbolize_keys
      end

      # This version returns an "empty" term hash if there is no URI.
      # This version caches results for efficiency.
      def term(uri)
        return { name: '', uri: '' } if uri.blank?
        @terms ||= {}
        return @terms[uri] if @terms.key?(uri)
        res = query(%Q{MATCH (term:Term { uri: "#{uri.gsub(/"/, '""')}" }) RETURN term})
        return nil unless res && res["data"] && res["data"].first
        @terms[uri] = res["data"].first.first
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def descendants_of_term(uri)
        terms = query(%Q{MATCH (term:Term)-[:parent_term|:synonym_of*]->(:Term { uri: "#{uri.gsub(/"/, '""')}" })
                         RETURN DISTINCT term})
        terms["data"].map { |r| r.first["data"] }
      end

      # TODO: SOMEONE ONE SHOULD MOVE THIS TO TraitBank::Term (new class)!
      def term_member_of(uri)
        terms = query(%Q{MATCH (:Term { uri: "#{uri.gsub(/"/, '""')}" })-[:parent_term|:synonym_of*]->(term:Term) RETURN term})
        terms["data"].map { |r| r.first }
      end

      # TODO: extract a Predicate class. There's a lot here and that's a logic way to break this up.

      # Keep checking the following methods for use in the codebase:
      def obj_terms_for_pred(pred_uri, orig_qterm = nil)
        qterm = orig_qterm.delete('"').downcase.strip
        Rails.cache.fetch("trait_bank/obj_terms_for_pred/#{I18n.locale}/#{pred_uri}/#{qterm}",
                          expires_in: CACHE_EXPIRATION_TIME) do
          name_field = Util::I18nUtil.term_name_property
          q = %Q{MATCH (object:Term { type: 'value',
                 is_hidden_from_select: false })-[:object_for_predicate]->(:Term{ uri: '#{pred_uri}' })}
          q += "\nWHERE #{term_name_prefix_match("object", qterm)}" if qterm
          q +=  "\nRETURN object ORDER BY object.position LIMIT #{DEFAULT_GLOSSARY_PAGE_SIZE}"
          res = query(q)
          res["data"] ? res["data"].map do |t|
            hash = t.first["data"].symbolize_keys
            hash[:name] = hash[:"#{name_field}"]
            hash
          end : []
        end
      end

      def any_obj_terms_for_pred?(pred)
        Rails.cache.fetch("trait_bank/pred_has_object_terms_2_checks/#{pred}", expires_in: CACHE_EXPIRATION_TIME) do
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)<-[:synonym_of|:parent_term*0..]-(:Term
              { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
          )["data"].any? ||
          query(
            %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)-[:synonym_of|:parent_term*0..]->(:Term
              { uri: '#{pred}'}) RETURN term.uri LIMIT 1}
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

      def any_direct_records_for_pred?(uri)
        key = "trait_bank/any_direct_records_for_pred?/#{uri}"
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = query(%{
            MATCH (t:Trait)-[:predicate]->(:Term{uri: "#{uri.gsub(/"/, '""')}"})
            RETURN t LIMIT 1
          })["data"]
          res.any?
        end
      end

      def parents_of_term(term_uri)
        result = query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:parent_term]->(parent:Term)
          RETURN DISTINCT parent.uri
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].first
      end

      def synonym_of_term(term_uri)
        result = query(%Q(
          MATCH (:Term{ uri: "#{term_uri}" })-[:synonym_of]->(parent:Term)
          RETURN parent.uri
          LIMIT 1
        ))
        return nil unless result&.key?('data') && !result['data'].empty? && !result['data'].first.empty?
        result['data'].first.first
      end

      def term_descendant_of_other?(term_uri, other_uri)
        result = query(%Q(
          MATCH p=(:Term{ uri: "#{term_uri}" })-[:parent_term*1..]->(:Term{ uri: "#{other_uri}" })
          RETURN p
          LIMIT 1
        ))

        result["data"].any?
      end

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
        return "0-9" unless term[:name]
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
          res = term(uri)
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

      private
      def term_name_prefix_match(label, qterm)
        "LOWER(#{label}.#{Util::I18nUtil.term_name_property}) =~ \"#{qterm.delete('"').downcase}.*\" "
      end
    end
  end
end
