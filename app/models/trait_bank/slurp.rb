class TraitBank::Slurp
  @max_csv_size = 1_000_000

  class << self
    delegate :query, to: TraitBank

    def load_resource_from_repo(resource)
      repo = ContentServerConnection.new(resource)
      repo.copy_file(resource.traits_file, 'traits.tsv')
      repo.copy_file(resource.meta_traits_file, 'metadata.tsv')
      TraitBank.create_resource(resource.id)
      load_csvs(resource)
      resource.remove_traits_files
    end

    def load_resource_metadata_from_repo(resource)
      repo = ContentServerConnection.new(resource)
      repo.copy_file(resource.meta_traits_file, 'metadata.tsv')
      config = load_csv_config(resource.id, single_resource: true)
      basename = File.basename()
      load_csv(basename, config[basename])
      # "Touch" the resource so that it looks like it's been changed (it has):
      resource.touch
      resource.remove_traits_files
    end

    def heal_traits(resource)
      repo = ContentServerConnection.new(resource)
      repo.copy_file(resource.traits_file, 'traits.tsv')
      repo.copy_file(resource.meta_traits_file, 'metadata.tsv')
      heal_traits_by_type("traits_#{resource.id}.csv", :Trait, resource.id)
      heal_traits_by_type("meta_traits_#{resource.id}.csv", :MetaTrait, resource.id)
      post_load_cleanup(resource.id)
      resource.remove_traits_files
    end

    # Same as load_csvs, the traits file there includes a resource_id column (the last column). This is intended for
    # multi-resource serialized clades.
    def load_full_csvs(id)
      config = load_csv_config(id, single_resource: false) # No specific resource!
      config.each { |filename, file_config| load_csv(filename, file_config, read_resources: id) }
      post_load_cleanup(id)
    end

    def load_csvs(resource)
      config = load_csv_config(resource.id, single_resource: true)
      config.each { |filename, file_config| load_csv(filename, file_config) }
      post_load_cleanup(resource.id)
      # "Touch" the resource so that it looks like it's been changed (it has):
      resource.touch
    end

    def post_load_cleanup(id)
      page_ids = read_field_from_traits_file(id, 'page_id').sort.uniq.compact
      return nil if page_ids.empty?
      fix_page_names_for_new_pages(page_ids)
    end

    def read_field_from_traits_file(id, field)
      file = Rails.public_path.join('data', "traits_#{id}.csv")
      # read the traits file and pluck out the page IDs...
      require 'csv'
      data = CSV.read(file)
      headers = data.shift
      return nil unless headers # Nothing in the file.
      return nil if headers.first == 'false' # The only thing in the file, when it's empty.
      position = headers.find_index(field)
      raise "Could not find #{field} field in traits_#{id}.csv." if position.nil?
      values = {}
      data.each do |row|
        values[row[position]] = true
      end
      values.keys
    end

    def fix_page_names_for_new_pages(page_ids)
      TraitBank::Denormalizer.set_canonicals_by_page_id(page_ids)
    end

    # TODO: (eventually) target_scientific_name: row.target_scientific_name
    def load_csv_config(id, options = {})
      single_resource = options[:single_resource]
      { "traits_#{id}.csv" =>
        { 'Page' => [:page_id],
          'Trait' => %i[
            eol_pk resource_pk source literal measurement object_page_id scientific_name normal_measurement sample_size
            citation source remarks method
          ],
          wheres: {
            # This will be applied to ALL rows:
            "1=1" => {
              matches: {
                predicate: 'Term { uri: row.predicate }',
                resource: "Resource { resource_id: #{single_resource ? id : 'row.resource_id'} }"
              },
              # NOTE: merges are expressed as a triple, e.g.: [source variable, relationship name, target variable]
              merges: [
                [:page, :trait, :trait],
                [:trait, :predicate, :predicate],
                [:trait, :supplier, :resource]
              ],
            },
            "#{is_not_blank('row.sex')}" =>
            {
              matches: { sex: 'Term { uri: row.sex }' },
              merges: [ [:trait, :sex_term, :sex] ]
            },
            "#{is_not_blank('row.lifestage')}" =>
            {
              matches: { lifestage: 'Term { uri: row.lifestage }' },
              merges: [ [:trait, :lifestage_term, :lifestage] ]
            },
            "#{is_not_blank('row.statistical_method')}" =>
            {
              matches: { statistical_method: 'Term { uri: row.statistical_method }' },
              merges: [ [:trait, :statistical_method_term, :statistical_method] ]
            },
            "#{is_blank('row.value_uri')} AND #{is_not_blank('row.units')}" =>
            {
              matches: { units: 'Term { uri: row.units }' },
              merges: [ [:trait, :units_term, :units] ]
            },
            "#{is_not_blank('row.normal_units_uri')}" =>
            {
              matches: { normal_units: 'Term { uri: row.normal_units_uri }' },
              merges: [ [:trait, :normal_units_term, :normal_units] ]
            },
            "#{is_not_blank('row.value_uri')} AND #{is_blank('row.units')}" =>
            {
              matches: { object_term: 'Term { uri: row.value_uri }' },
              merges: [ [:trait, :object_term, :object_term] ]
            }
          }
        },

        "meta_traits_#{id}.csv" =>
        {
          'MetaData' => %i[eol_pk source literal measurement],
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
            },
            "#{is_not_blank('row.sex')}" =>
            {
              matches: { sex: 'Term { uri: row.sex }' },
              merges: [ [:metadata, :sex_term, :sex] ]
            },
            "#{is_not_blank('row.lifestage')}" =>
            {
              matches: { lifestage: 'Term { uri: row.lifestage }' },
              merges: [ [:metadata, :lifestage_term, :lifestage] ]
            },
            "#{is_not_blank('row.statistical_method')}" =>
            {
              matches: { statistical_method: 'Term { uri: row.statistical_method }' },
              merges: [ [:metadata, :statistical_method_term, :statistical_method] ]
            },
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

    def load_csv(filename, config, params = {})
      wheres = config.delete(:wheres)
      nodes = config # what's left.
      if params[:read_resources]
        res_ids = read_field_from_traits_file(params[:read_resources], 'resource_id')
        return nil if res_ids.nil?
        res_ids.each do |resource_id|
          TraitBank.create_resource(resource_id)
        end
      end
      wheres.each do |clause, where_config|
        break_up_large_files(filename) do |sub_filename|
          load_csv_where(clause, filename: sub_filename, config: where_config, nodes: nodes)
        end
      end
    end

    def break_up_large_files(filename)
      line_count = size_of_file(filename)
      if line_count < @max_csv_size
        yield filename
      else
        break_up_large_file(filename, line_count) do |sub_filename|
          yield sub_filename
        end
      end
    end

    def break_up_large_file(filename, line_count)
      basename = File.basename(filename, '.*') # It's .csv, but I want to be safe...
      lines_without_header = line_count - 1
      chunks = lines_without_header / @max_csv_size # NOTE: without #ceil and #to_f, this yields a floor!
      tail = lines_without_header % @max_csv_size
      # NOTE: Each one of these head/tail commands can take a few seconds.
      (1..chunks).each do |chunk|
        sub_file = sub_file_name(basename, chunk)
        copy_head(filename, sub_file)
        `head -n #{@max_csv_size * chunk + 1} #{trait_file_path}/#{filename} | tail -n #{@max_csv_size} >> #{trait_file_path}/#{sub_file}`
        yield sub_file
        File.unlink("#{trait_file_path}/#{sub_file}")
      end
      unless tail.zero?
        sub_file = sub_file_name(basename, chunks + 1)
        copy_head(filename, sub_file)
        `tail -n #{tail} #{trait_file_path}/#{filename} >> #{trait_file_path}/#{sub_file}`
        yield sub_file
        File.unlink("#{trait_file_path}/#{sub_file}")
      end
    end

    def size_of_file(filename)
      # NOTE: Just this word-count can take a few seconds on a large file!
      `wc -l #{trait_file_path}/#{filename}`.strip.split(' ').first.to_i
    end

    def copy_head(filename, sub_file)
      `head -n 1 #{trait_file_path}/#{filename} > #{trait_file_path}/#{sub_file}`
    end

    def sub_file_name(basename, chunk)
      "#{basename}_chunk_#{chunk}.csv"
    end

    # TODO: this is really all wrong. We should be passing around the path, but when I looked into doing that, it became
    # obvious that this shouldn't be done with class methods, but an instance that can store at least the resource, if
    # not also the path being used. So, for now, I am just hacking it. Sigh.
    def trait_file_path
      Rails.public_path.join('data')
    end

    def heal_traits_by_type(filename, label, resource_id)
      file = filename =~ /\// ? filename : "#{Rails.public_path}/#{filename}"
      position = nil
      correct_pks = Set.new
      CSV.foreach(file) do |row|
        if position.nil?
          position = row.index { |c| c.downcase.gsub(/^\s+/, '').gsub(/\s+$/, '') == 'eol_pk' }
          raise("CANNOT FIND eol_pk COLUMN IN #{file}!") unless position
        else
          correct_pks << row[position]
        end
      end
      data = query("MATCH (:Resource { resource_id: #{resource_id} })<-[:supplier]-(n:#{label}) "\
        "RETURN n.eol_pk")
      traitbank_pks = Set.new
      data['data'].each { |row| traitbank_pks << row.first }
      extra_pks = traitbank_pks - correct_pks
      raise "Ooops! This resource has been copmpletely reharvested; you need to re-publish it entirely." if
        extra_pks.size == traitbank_pks.size
      return 0 if extra_pks.size.zero?
      extra_pks.to_a.in_groups_of(1000) do |pks|
        TraitBank::Admin.remove_with_query(
          name: node,
          q: "(node:#{label}) WHERE node.eol_pk IN ['#{pks.join("','")}']"
        )
      end
      extra_pks.size
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

    def csv_query_head(filename, where_clause = nil)
      where_clause ||= '1=1'
      file = filename =~ /^http/ ? filename : "#{Rails.configuration.eol_web_url}/data/#{File.basename(filename)}"
      "USING PERIODIC COMMIT LOAD CSV WITH HEADERS FROM '#{file}' AS row WITH row WHERE #{where_clause} "
    end

    # TODO: extract the file-writing to a method that takes a block.
    def build_ancestry
      require 'csv'
      old_version = get_old_ancestry_version
      new_version = old_version + 1
      # NOTE: batch size of 10_000 was a bit too slow, and imagine it'll get worse with more pages.
      Page
        .includes(native_node: :parent)
        .joins(native_node: :parent)
        .where("nodes.resource_id = #{Resource.native.id}")
        .find_in_batches(batch_size: 5_000) do |group|
        first_id = group.first.id
        last_id = group.last.id
        CSV.open(ancestry_file_path, 'w') do |csv|
          csv << ['page_id', 'parent_id']
          group.each do |page|
            next if page.native_node.parent.page_id.nil?
            csv << [page.id, page.native_node.parent.page_id]
          end
        end
        rebuild_ancestry_group('ancestry.csv', new_version)
      end
      remove_ancestry(old_version) # You can't run this twice on the same resource without downtime.
    end

    def get_old_ancestry_version
      r = query("MATCH (p:Page)-[rel:parent]->(:Page) RETURN MAX(rel.ancestry_version)")
      return 0 unless r&.is_a?(Hash)
      r['data'].first.first.to_i
    end

    def remove_ancestry(old_version)
      # I am worried this will timeout when we have enough of them. Already takes 24s with a 10th of what we'll have...
      TraitBank::Admin.remove_with_query(
        name: :rel,
        q: "MATCH (p:Page)-[rel:parent {ancestry_version: #{old_version}}]->(:Page) DELETE rel"
      )
    end

    def ancestry_file_path
      @ancestry_file_path ||= Rails.public_path.join('data', 'ancestry.csv')
    end

    def rebuild_ancestry_group(file, version)
      # Nuke it from orbit:
      execute_clauses([csv_query_head(file), 'MERGE (:Page { page_id: toInt(row.page_id) })'])
      execute_clauses([csv_query_head(file), 'MERGE (:Page { page_id: toInt(row.parent_id) })'])
      execute_clauses([csv_query_head(file),
                      'MATCH (page:Page { page_id: toInt(row.page_id) })',
                      'MATCH (parent:Page { page_id: toInt(row.parent_id) })',
                      "MERGE (page)-[:parent { ancestry_version: #{version} }]->(parent)"])
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
