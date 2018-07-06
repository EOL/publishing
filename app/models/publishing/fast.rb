class Publishing::Fast
  require 'net/http'
  attr_accessor :data_file, :log

  def self.by_resource(resource)
    publr = new(resource)
    publr.by_resource
  end

  # e.g.: Publishing::Fast.update_attribute_by_resource(Resource.first, Node, :rank_id)
  def self.update_attribute_by_resource(resource, klass, field)
    publr = new(resource)
    publr.update_attribute(klass, field)
  end

  # e.g.: Publishing::Fast.load_local_file(Resource.first, NodeAncestor, '/some/path/to/tmp/DWH_node_ancestors.tsv')
  def self.load_local_file(resource, klass, file)
    publr = new(resource)
    publr.load_local_file(klass, file)
  end

  def load_local_file(klass, file)
    @klass = klass
    @data_file = file
    log_start("One-shot manual import of #{@klass} starting...")
    log_start("#import #{@klass}")
    import
    log_start("#propagate_ids #{@klass}")
    propagate_ids
    log_start("One-shot manual import of #{@klass} COMPLETED.")
  end

  def initialize(resource, log = nil)
    @start_at = Time.now
    @resource = resource
    repo_url = Rails.application.secrets.repository['url']
    @repo_site = URI(repo_url)
    @repo_is_on_this_host = repo_url =~ /(128\.0\.0\.1|localhost)/
    @log = log # Okay if it's nil.
    @files = []
  end

  # NOTE: this does NOT work for traits. Don't try. You'll need to make a different method for that.
  def update_attribute(klass, field)
    require 'csv'
    abort_if_already_running
    @klass = klass
    # NOTE: Minus one for the id, which is NEVER in the file but is ALWAYS the first column in the table:
    pos = @klass.column_names.index(field) - 1
    new_log
    begin
      plural = @klass.table_name
      unless exists?("#{plural}.tsv")
        raise("#{repo_file_url("#{plural}.tsv")} does not exist! Are you sure the resource has successfully finished harvesting?")
      end
      log_start("Updating attribute #{field} (#{pos}) for #{plural}")
      @data_file = Rails.root.join('tmp', "#{@resource.path}_#{plural}.tsv")
      if grab_file("#{plural}.tsv")
        all_data = CSV.read(@data_file, col_sep: "\t", encoding: 'ISO-8859-1')
        pk_pos = @klass.column_names.index('resource_pk') - 1
        all_data.in_groups_of(2000, false) do |lines|
          pks = lines.map { |l| l[pk_pos] }
          instances = @klass.where(resource_id: @resource.id, resource_pk: pks)
          keyed_instances = instances.group_by(&:resource_pk)
          changes = []
          lines.each do |line|
            pk = line[pk_pos]
            val = line[pos]
            keyed_instances[pk].each do |instance|
              next if instance[field] == val
              instance[field] = val
              changes << instance
            end
          end
          @klass.import(changes, on_duplicate_key_update: [field])
        end
        @files << @data_file
      end
    rescue => e
      @log.fail(e)
    ensure
      log_end("TOTAL TIME: #{Time.delta_str(@start_at)}")
      log_close
      ImportLog.all_clear!
    end
  end

  def by_resource
    @relationships = {
      Referent => {},
      Node => { parent_id: Node },
      Identifier => { node_id: Node },
      ScientificName => { node_id: Node },
      NodeAncestor => { node_id: Node, ancestor_id: Node },
      Vernacular => { node_id: Node },
      # Yes, really, there is no ling to nodes or pages on Article or Medium; these are managed with PageContent.
      Article => {},
      Medium => {},
      Attribution => { content_id: [Medium, Article] }, # Polymorphic implied with array.
      ImageInfo => { medium_id: Medium },
      Reference => { referent_id: Referent } # The polymorphic relationship is handled specially.
    }
    abort_if_already_running
    new_log
    unless @resource.nodes.count.zero? # slow, skip if not needed.
      log = @resource.remove_content
      @log = Publishing::PubLog.new(@resource)
      log.each { |msg| log_warn(msg) }
      log_warn('All existing content has been destroyed for the resource.')
    end
    begin
      unless exists?('nodes.tsv')
        raise("#{repo_file_url('nodes.tsv')} does not exist! Are you sure the resource has successfully finished harvesting?")
      end
      @relationships.each_key do |klass|
        @klass = klass
        log_start(@klass)
        @data_file = Rails.root.join('tmp', "#{@resource.path}_#{@klass.table_name}.tsv")
        if grab_file("#{@klass.table_name}.tsv")
          log_start("#import #{@klass}")
          import
          log_start("#propagate_ids #{@klass}")
          propagate_ids
          @files << @data_file
        end
      end
      log_start('Remove traits')
      TraitBank::Admin.remove_for_resource(@resource)
      log_start('#publish_traits')
      begin
        publish_traits
      rescue => e
        log_warn("Trait Publishing failed: #{e.message}")
      end
      # TODO: you also have to do associations (but not here; on the other repo)!
      log_start('PageCreator')
      PageCreator.by_node_pks(node_pks, @log, skip_reindex: true)
      if page_contents_required?
        log_start('MediaContentCreator')
        MediaContentCreator.by_resource(@resource, log: @log)
      end
      log_start('#fix_native_nodes')
      @resource.fix_native_nodes
      log_start('#propagate_reference_ids')
      propagate_reference_ids
      clean_up
    rescue => e
      @log.fail(e)
    ensure
      log_end("TOTAL TIME: #{Time.delta_str(@start_at)}")
      log_close
      ImportLog.all_clear!
    end
  end

  def abort_if_already_running
    if (info = ImportLog.already_running?)
      raise(info)
    end
  end

  def new_log
    @log ||= Publishing::PubLog.new(@resource) # you MIGHT want @resource.import_logs.last
  end

  def clean_up
    @files.each do |file|
      log("Removing #{file}")
      File.unlink(file)
    end
  end

  def repo_file_url(name)
    "/data/#{@resource.path}/publish_#{name}"
  end

  def exists?(name)
    url = URI.parse(repo_file_url(name))
    req = Net::HTTP.new(@repo_site.host, @repo_site.port)
    res = req.request_head(url.path)
    res.code.to_i < 400
  end

  def grab_file(name)
    url = repo_file_url(name)
    resp = nil
    result = Net::HTTP.start(@repo_site.host, @repo_site.port) do |http|
      resp = http.get(url)
    end
    unless result.code.to_i < 400
      log_warn("MISSING #{@repo_site}#{url} [#{result.code}] (#{resp.size} bytes); skipping")
      return false
    end
    open(@data_file, 'wb') { |file| file.write(resp.body) }
  end

  def import
    cols = @klass.column_names
    cols.delete('id') # We never load the PK, since it's auto_inc.
    q = ['LOAD DATA']
    # NOTE: "LOCAL" is a strange directive; you only use it when you are REMOTE. ...The intention being, you're telling
    # the remote server "the file I'm talking about is local to me." Confusing at best. I don't like it.
    q << 'LOCAL' unless @repo_is_on_this_host
    q << "INFILE '#{@data_file}'"
    q << "INTO TABLE `#{@klass.table_name}`"
    q << "(#{cols.join(',')})"
    begin
      @klass.connection.execute(q.join(' '))
    rescue => e
      puts 'FAILED TO LOAD DATA. NOTE that it\'s possible you need to A) In Mysql,'
      puts 'GRANT FILE ON *.* TO your_user@localhost IDENTIFIED BY "your_password";'
      puts '...and B) add "local_infile=true" to your database.yml config for this to work.'
      raise e
    end
  end

  def propagate_ids
    @relationships[@klass].each do |field, sources|
      next unless sources
      Array(sources).each do |source| # Array implies polymorphic relationship
        # This is a little weird, so I'll explain. CURRENTLY, "field" is populated with the IDs FROM THE HARVEST DB. So
        # this code is joining the two tables via that harv_db_id, then re-setting the field with the REAL id (from THIS
        # DB).
        @klass.propagate_id(fk: field, other: "#{source.table_name}.harv_db_id",
                            set: field, with: 'id', resource_id: @resource.id)
      end
    end
  end

  def propagate_reference_ids
    return nil if Reference.where(resource_id: @resource.id).count.zero?
    [Node, ScientificName, Medium, Article].each do |klass|
      next if Reference.where(resource_id: @resource.id, parent_type: klass.to_s).count.zero?
      min = Reference.where(resource_id: @resource.id, parent_type: klass.to_s).minimum(:id)
      max = Reference.where(resource_id: @resource.id, parent_type: klass.to_s).maximum(:id)
      page_size = 100_000
      clauses = []
      clauses << "UPDATE `references` t JOIN `#{klass.table_name}` o ON (t.parent_id = o.harv_db_id"
      clauses << "AND t.resource_id = #{@resource.id} AND t.parent_type = '#{klass}')"
      clauses << "SET t.parent_id = o.id"
      # TODO: this logic was pulled from config/initializers/propagate_ids.rb ; extract!
      if max - min > page_size
        while max > min
          upper = min + page_size - 1
          clauses << "WHERE t.id >= #{min} AND t.id <= #{upper}"
          ActiveRecord::Base.connection.execute(clauses.join(' '))
          also_propagate_referents(klass, min: min, upper: upper)
          min += page_size
        end
      else
        ActiveRecord::Base.connection.execute(clauses.join(' '))
        also_propagate_referents(klass)
      end
    end
  end

  def also_propagate_referents(klass, options = {})
    clauses = []
    clauses << "UPDATE `references` t JOIN referents o ON (t.referent_id = o.harv_db_id"
    clauses << "AND t.resource_id = #{@resource.id} AND t.parent_type = '#{klass}')"
    clauses << "SET t.referent_id = o.id"
    clauses << "WHERE t.id >= #{options[:min]} AND t.id <= #{options[:upper]}" if options[:min]
    ActiveRecord::Base.connection.execute(clauses.join(' '))
  end

  def publish_traits
    @data_file = @resource.traits_file
    grab_file('traits.tsv')
    @data_file = @resource.meta_traits_file
    grab_file('metadata.tsv')
    TraitBank.create_resource(@resource.id)
    TraitBank::Slurp.load_csvs(@resource)
    @resource.remove_traits_files
  end

  def page_contents_required?
    Medium.where(resource_id: @resource.id).any? || Article.where(resource_id: @resource.id).any?
  end

  def node_pks
    Node.where(resource_id: @resource.id).pluck(:resource_pk)
  end

  def log_start(what)
    @log.log(what.to_s, cat: :starts)
  end

  def log_end(what)
    @log.log(what.to_s, cat: :ends)
  end

  def log_warn(what)
    @log.log(what.to_s, cat: :warns)
  end

  def log(what)
    @log.log(what.to_s, cat: :infos)
  end

  def log_close
    @log.complete
  end
end
