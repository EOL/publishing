class TraitBank::Slurp
  class << self
    delegate :query, to: TraitBank

    def load_csvs(resource)
      config = load_csv_config(resource)
      config.each { |filename, file_config| load_csv(filename, file_config) }
    end

    # TODO: (eventually) target_scientific_name: row.target_scientific_name
    def load_csv_config(resource)
      { "traits_#{resource.id}.csv" =>
        { 'Page' => [:page_id],
          'Trait' => %i[eol_pk resource_pk sex lifestage statistical_method source literal measurement\
                        object_page_id scientific_name],
          wheres: {
            # This will be applied to ALL rows:
            "1=1" => {
              matches: {
                predicate: 'Term { uri: row.predicate }',
                resource: "Resource { resource_id: #{resource.id} }"
              },
              merges: [
                [:page, :trait, :trait],
                [:trait, :predicate, :predicate],
                [:trait, :supplier, :resource]
              ],
            }, # default
            "#{is_blank('row.value_uri')} AND #{is_not_blank('row.units')}" =>
            {
              matches: { units: 'Term { uri: row.units }' },
              merges: [ [:trait, :units_term, :units] ]
            },
            "#{is_not_blank('row.value_uri')} AND #{is_blank('row.units')}" =>
            {
              matches: { object_term: 'Term { uri: row.value_uri }' },
              merges: [ [:trait, :object_term, :object_term] ]
            }
          }
        },

        "meta_traits_#{resource.id}.csv" =>
        {
          'MetaData' => %i[eol_pk sex lifestage statistical_method source literal measurement],
          wheres: {
            "1=1" => { # ALL ROWS
              matches: {
                trait: 'Trait { eol_pk: row.trait_eol_pk }',
                predicate: 'Term { uri: row.predicate }'
              },
              merges: [
                [:trait, :metadata, :metadata],
                [:metadata, :predicate, :predicate]
              ],
            }, # default
            "#{is_blank('row.value_uri')} AND #{is_not_blank('row.units')}" =>
            {
              matches: { units: 'Term { uri: row.units }' },
              merges: [ [:metadata, :units_term, :units] ]
            },
            "#{is_not_blank('row.value_uri')} AND #{is_blank('row.units')}" =>
            {
              matches: { object_term: 'Term { uri: row.value_uri }' },
              merges: [ [:metadata, :object_term, :object_term] ]
            }
          }
        }
      }
    end

    def load_csv(filename, config)
      wheres = config.delete(:wheres)
      nodes = config # what's left.
      wheres.each do |clause, where_config|
        load_csv_where(clause, filename: filename, config: where_config, nodes: nodes)
      end
    end

    def load_csv_where(clause, options = {})
      filename = options[:filename]
      config = options[:config]
      nodes = options[:nodes] # NOTE: this is neo4j "nodes", not EOL "Node"; unfortunate collision.
      merges = Array(config[:merges])
      matches = config[:matches]
      head = csv_query_head(filename, clause)
      # First, build all of the nodes:
      nodes.each { |label, attributes| build_nodes(label: label, attributes: attributes, head: head) }
      # Then the merges, one at a time:
      merges.each { |triple| merge_triple(triple: triple, head: head, nodes: nodes, matches: matches) }
    end

    def csv_query_head(file, where_clause = nil)
      where_clause ||= '1=1'
      "USING PERIODIC COMMIT LOAD CSV WITH HEADERS FROM '#{Rails.configuration.eol_web_url}/#{file}' AS row WITH row WHERE #{where_clause}"
    end

    # TODO: extract the file-writing to a method that takes a block.
    def rebuild_ancestry
      require 'csv'
      puts '(starts) .rebuild_ancestry'
      # I am worried this will timeout when we have enough of them. Already takes 24s with a 10th of what we'll have...
      puts "(infos) delete relationships"
      TraitBank.query("MATCH (p:Page)-[rel:parent]->(:Page) DELETE rel")
      filename = "ancestry.csv"
      file_with_path = Rails.public_path.join(filename)
      # NOTE: batch size of 10_000 was a bit too slow, and imagine it'll get worse with more pages.
      Page
        .includes(native_node: :parent)
        .joins(native_node: :parent)
        .where('nodes.resource_id = 1') # AGAIN: Resource 1 is HARD-CODED to EOL's DH. It must be.
        .find_in_batches(batch_size: 5_000) do |group|
        first_id = group.first.id
        last_id = group.last.id
        puts "(infos) Pages #{first_id} - #{last_id}"
        puts "(infos) write CSV"
        CSV.open(file_with_path, 'w') do |csv|
        csv << ['page_id', 'parent_id']
          group.each do |page|
            next if page.native_node.parent.page_id.nil?
            csv << [page.id, page.native_node.parent.page_id]
          end
        end
        puts "(infos) add relationships"
        rebuild_ancestry_group(filename)
      end
      puts '(ends) .rebuild_ancestry'
    end

    def rebuild_ancestry_group(file)
      # Nuke it from orbit:
      execute_clauses([csv_query_head(file), 'MERGE (:Page { page_id: toInt(row.page_id) })'])
      execute_clauses([csv_query_head(file), 'MERGE (:Page { page_id: toInt(row.parent_id) })'])
      execute_clauses([csv_query_head(file),
                      'MATCH (page:Page { page_id: toInt(row.page_id) })',
                      'MATCH (parent:Page { page_id: toInt(row.parent_id) })',
                      'MERGE (page)-[:parent]->(parent)'])
    end

    def execute_clauses(clauses)
      query(clauses.join("\n"))
    end

    def build_nodes(options)
      label = options[:label]
      attributes = options[:attributes].dup
      head = options[:head]
      name = label.downcase
      pk = attributes.shift # Pull the first attribute off...
      pk_val = autocast_val("row.#{pk}")
      q = "#{head}MERGE (#{name}:#{label} { #{pk}: #{pk_val} })"
      attribute_sets = []
      attributes.each do |attribute|
        value = autocast_val("row.#{attribute}")
        q << set_attribute(name, attribute, value, 'CREATE')
        q << set_attribute(name, attribute, value, 'MATCH')
      end
      query(q)
    end

    # NOTE: This code automatically makes integers out of any attribute ending in "_id" or "_num". BE AWARE!
    def autocast_val(value)
      # NOTE: This code automatically makes integers out of any attribute ending in "_id" or "_num". BE AWARE!
      value = "toInt(#{value})" if value =~ /_(num|id)$/
      value
    end

    def merge_triple(options)
      triple = options[:triple]
      head = options[:head]
      nodes = options[:nodes]
      matches = options[:matches]
      # merges: [ [:trait, :units_term, :units] ]
      # NOTE: #to_s to make matching simpler.
      subj = triple[0].to_s
      pred = triple[1].to_s
      obj  = triple[2].to_s
      q = head
      # MATCH any required nodes:
      nodes.each do |label, attributes|
        name = label.downcase
        next unless subj == name || obj == name
        pk = attributes.first
        pk_val = autocast_val("row.#{pk}")
        q += "\nMATCH (#{name}:#{label} { #{pk}: #{pk_val} })"
      end
      # MATCH any ... uhhh... matches required:
      matches.each do |name, match|
        # matches: { object_term: ':Term { uri: row.value_uri }' },
        name = name.to_s
        next unless subj == name || obj == name
        q += "\nMATCH (#{name}:#{match})"
      end
      # Then merge the triple:
      query("#{q}\nMERGE (#{subj})-[:#{pred}]->(#{obj})")
    end

    def set_attribute(name, attribute, value, on_set)
      "\nON #{on_set} SET #{name}.#{attribute} = #{value}"
    end

    def is_not_blank(field)
      "(#{field} IS NOT NULL AND TRIM(#{field}) <> '')"
    end

    def is_blank(field)
      "(#{field} IS NULL OR TRIM(#{field}) = '')"
    end
  end
end
