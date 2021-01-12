module TraitBank
  module Queries
    class << self
      include TraitBank::Constants

      def quote(string)
        return string if string.is_a?(Numeric) || string =~ /\A[-+]?[0-9,]*\.?[0-9]+\Z/
        %Q{"#{string.gsub(/"/, "\\\"")}"}
      end

      def limit_and_skip_clause(page = 1, per = 50)
        # I don't know why the default values don't work, but:
        page ||= 1
        per ||= 50
        skip = (page.to_i - 1) * per.to_i
        add = " LIMIT #{per}"
        add = " SKIP #{skip}#{add}" if skip > 0
        add
      end

      def count
        res = TraitBank::Connector.query("MATCH (trait:Trait)<-[#{TRAIT_RELS}]-(page:Page) WITH count(trait) as count RETURN count")
        res["data"] ? res["data"].first.first : false
      end

      def count_by_resource(id)
        Rails.cache.fetch("trait_bank/count_by_resource/#{id}") do
          count_relationships_and_nodes_by_resource_no_cache(id)
        end
      end

      def count_relationships_and_nodes_by_resource_no_cache(id)
        res = TraitBank::Connector.query(
          "MATCH (res:Resource { resource_id: #{id} })<-[:supplier]-(trait:Trait)<-[#{TRAIT_RELS}]-(page:Page) "\
          "USING INDEX res:Resource(resource_id) "\
          "WITH count(trait) as count "\
          "RETURN count")
        res["data"] ? res["data"].first.first : false
      end

      def count_by_resource_and_page(resource_id, page_id)
        Rails.cache.fetch("trait_bank/count_by_resource/#{resource_id}/pages/#{page_id}") do
          res = TraitBank::Connector.query(
            "MATCH (res:Resource { resource_id: #{resource_id} })<-[:supplier]-(trait:Trait)<-[#{TRAIT_RELS}]-(page:Page { page_id: #{page_id} }) "\
            "USING INDEX res:Resource(resource_id) USING INDEX page:Page(page_id) "\
            "WITH count(trait) as count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : false
        end
      end

      def count_by_page(page_id)
        Rails.cache.fetch("trait_bank/count_by_page/#{page_id}", expires_in: 1.day) do
          res = TraitBank::Connector.query(
            "MATCH (trait:Trait)<-[#{TRAIT_RELS}]-(page:Page { page_id: #{page_id} }) "\
            "WITH count(trait) as count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : false
        end
      end

      def predicate_count_by_page(page_id)
        Rails.cache.fetch("trait_bank/predicate_count_by_page/#{page_id}", expires_in: 1.day) do
          res = TraitBank::Connector.query(
            "MATCH (page:Page { page_id: #{page_id} }) -[#{TRAIT_RELS}]->"\
            "(trait:Trait)-[:predicate]->(term:Term) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : 0
        end
      end

      def predicate_count
        Rails.cache.fetch("trait_bank/predicate_count", expires_in: 1.day) do
          res = TraitBank::Connector.query(
            "MATCH (trait:Trait)-[:predicate]->(term:Term) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count")
          res["data"] ? res["data"].first.first : false
        end
      end

      def order_clause(options)
        %Q{ ORDER BY #{order_clause_array(options).join(", ")}}
      end

      def trait_exists?(resource_id, pk)
        raise "NO resource ID!" if resource_id.blank?
        raise "NO resource PK!" if pk.blank?
        res = TraitBank::Connector.query(
          "MATCH (trait:Trait { resource_pk: #{quote(pk)} })"\
          "-[:supplier]->(res:Resource { resource_id: #{resource_id} }) "\
          "RETURN trait")
        res["data"] ? res["data"].first : false
      end

      # NOTE: this method is unused in the code, it's here for convenience when debugging.
      def by_eol_pk(eol_pk)
        by_trait_and_page({id: eol_pk}, nil)
      end

      def by_trait_and_page(input, page_id, page = 1, per = 200)
        id = input.is_a?(Hash) ? input[:id] : input # Handle both raw IDs *and* actual trait hashes.
        page_id_part = page_id.nil? ? "" : "{ page_id: #{page_id} }"
        trait_rel = page_id.nil? ? ":trait" : TRAIT_RELS
        q = %{MATCH (page:Page#{page_id_part})
            -[#{trait_rel}]->(trait:Trait { eol_pk: "#{id.gsub(/"/, '""')}" })
            -[:supplier]->(resource:Resource),
            (trait:Trait)-[:predicate]->(predicate:Term)-[:parent_term|:synonym_of*0..]->(group_predicate:Term)
            WHERE NOT (group_predicate)-[:synonym_of]->(:Term)
            WITH group_predicate, head(collect({ page: page, trait: trait, predicate: predicate, resource: resource })) AS row
            LIMIT 1
            WITH group_predicate, row.page AS page, row.trait AS trait, row.predicate AS predicate, row.resource AS resource
            OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
            OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
            OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
            OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
            OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
            OPTIONAL MATCH (trait)-[:object_page]->(object_page:Page)
            OPTIONAL MATCH (trait)-[data]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)
            OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term)
            OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term)
            RETURN group_predicate, resource, trait, predicate, object_term, object_page, units, sex_term, lifestage_term, statistical_method_term,
              meta, meta_predicate, meta_units_term, meta_object_term, page }
            # ORDER BY LOWER(meta_predicate.name)}
        q += limit_and_skip_clause(page, per)
        res = TraitBank::Connector.query(q)
        TraitBank::ResultHandling.build_trait_array(res, group_meta_by_predicate: true)
      end

      def data_dump_trait(pk)
        id = pk.gsub(/"/, '""')
        TraitBank::Connector.query(%{
          MATCH (trait:Trait { eol_pk: "#{id}" })-[:metadata]->(meta:MetaData)-[:predicate]->(meta_predicate:Term)
          OPTIONAL MATCH (meta)-[:units_term]->(meta_units_term:Term)
          OPTIONAL MATCH (meta)-[:object_term]->(meta_object_term:Term)
          OPTIONAL MATCH (meta)-[:sex_term]->(sex_term:Term)
          OPTIONAL MATCH (meta)-[:lifestage_term]->(lifestage_term:Term)
          OPTIONAL MATCH (meta)-[:statistical_method_term]->(statistical_method_term:Term)
          RETURN meta.eol_pk, trait.eol_pk, meta_predicate.uri, meta.literal, meta.measurement, meta_object_term.uri,
            meta_units_term.uri, sex_term.uri, lifestage_term.uri, statistical_method_term.uri, meta.source
        })
      end
      alias_method :by_eol_pk, :data_dump_trait

      def by_page(page_id, page = 1, per = 100)
        Rails.cache.fetch("trait_bank/by_page/#{page_id}", expires_in: 1.day) do
          q = "MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)"\
              "-[:supplier]->(resource:Resource) "\
            "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
            "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
            "OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term) "\
            "OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term) "\
            "OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term) "\
            "OPTIONAL MATCH (trait)-[:units_term]->(units:Term) "\
            "OPTIONAL MATCH (trait)-[:object_page]->(object_page:Page) "\
            "RETURN resource, trait, predicate, object_term, object_page, units, sex_term, lifestage_term, statistical_method_term"

          # q += order_clause(by: ["LOWER(predicate.name)", "LOWER(object_term.name)",
          #   "LOWER(trait.literal)", "trait.normal_measurement"])
          q += limit_and_skip_clause(page, per)
          res = TraitBank::Connector.query(q)
          TraitBank::ResultHandling.build_trait_array(res)
        end
      end

      def data_dump_page(page_id)
        TraitBank::Connector.query(%{
          MATCH (page:Page { page_id: #{page_id} })-[#{TRAIT_RELS}]->(trait:Trait)-[:supplier]->(resource:Resource),
            (trait:Trait)-[:predicate]->(predicate:Term)
          OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term)
          OPTIONAL MATCH (trait)-[:sex_term]->(sex_term:Term)
          OPTIONAL MATCH (trait)-[:lifestage_term]->(lifestage_term:Term)
          OPTIONAL MATCH (trait)-[:statistical_method_term]->(statistical_method_term:Term)
          OPTIONAL MATCH (trait)-[:units_term]->(units:Term)
          OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units:Term)
          RETURN trait.eol_pk, page.page_id, trait.scientific_name, trait.resource_pk, predicate.uri, sex_term.uri,
            lifestage_term.uri, statistical_method_term.uri, trait.source, trait.object_page_id,
            trait.target_scientific_name, object_term.uri, trait.literal, trait.measurement, units.uri,
            trait.normal_measurement, normal_units.uri, resource.resource_id
        })
      end

      # TODO: add association to the sort... normal_measurement comes after literal, so it will be ignored
      def order_clause_array(options)
        options[:sort] ||= ""
        options[:sort_dir] ||= ""
        sorts =
          if options[:by]
            options[:by]
          elsif options[:object_term]
            [] # You already have a SINGLE term. Don't sort it.
          elsif options[:sort].downcase == "measurement"
            ["trait.normal_measurement"]
          else
            # TODO: this is not good. multiple types of values will not
            # "interweave", and the only way to change that is to store a
            # "normal_value" value for all different "stringy" types (literals,
            # object terms, and object page names). ...This is a resonable approach,
            # though it will require more work to keep "up to date" (e.g.: if the
            # name of an object term changes, all associated traits will have to
            # change).
            ["LOWER(predicate.name)", "LOWER(info_term.name)", "trait.normal_measurement", "LOWER(trait.literal)"]
          end
        # NOTE: "ties" for traits are resolved by species name.
        sorts << "page.name" unless options[:by]
        if options[:sort_dir].downcase == "desc"
          sorts.map! { |sort| "#{sort} DESC" }
        end
        sorts
      end

      def resource_filter_part(resource_id)
        if resource_id
          "{ resource_id: #{resource_id} }"
        else
          ""
        end
      end


      def predicate_filter_match_part(options)
        options[:pred_uri] ? "-[#{PARENT_TERMS}]->(:Term{ uri: '#{options[:pred_uri]}' })" : ""
      end
    end
  end
end
