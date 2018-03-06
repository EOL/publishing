class Publishing::Fast
  require 'net/http'

  def self.by_resource(resource)
    publr = new(resource)
    publr.by_resource
  end

  def initialize(resource)
    @start_at = Time.now
    @resource = resource
    @repo_site = URI(Rails.application.secrets.repository['url'])
    @relationships = {
      Referent => {},
      Node => { parent_id: Node },
      Identifier => { node_id: Node },
      ScientificName => { node_id: Node },
      NodeAncestor => { node_id: Node, ancestor_id: Node },
      Vernacular => { node_id: Node },
      Article => {}, # Yes, really, nothing; these are managed with PageContent.
      Medium => {}, # Yes, really, nothing; these are managed with PageContent.
      ImageInfo => { image_id: Medium },
      Reference => { referent_id: Referent } # The polymorphic relationship is handled specially.
    }
  end

  def by_resource
    @resource.remove_content unless @resource.nodes.count.zero? # slow, skip if not needed.
    @log = Publishing::PubLog.new(@resource)
    begin
      unless exists?('nodes')
        raise('Nodes TSV does not exist! Are you sure the resource has successfully finished harvesting?')
      end
      log_start('#remove_content')
      log_warn('All existing content has been destroyed for the resource.')
      files = []
      @resource_path = @resource.abbr.gsub(/\s+/, '_')
      @relationships.each_key do |klass|
        @klass = klass
        log_start(@klass)
        @data_file = Rails.root.join('tmp', "#{@resource_path}_#{@klass.table_name}.tsv")
        if grab_file(@klass.table_name)
          log_start("#import #{@klass}")
          import
          log_start("#propagate_ids #{@klass}")
          propagate_ids
          files << @data_file
        end
      end
      log_start('Remove traits')
      TraitBank::Admin.remove_for_resource(@resource)
      log_start('#publish_traits')
      publish_traits
      # TODO: you also have to do associations (but not here; on the other repo)!
      log_start('PageCreator')
      PageCreator.by_node_pks(node_pks, @log, skip_reindex: true)
      if page_contents_required?
        log_start('MediaContentCreator')
        MediaContentCreator.by_resource(@resource, @log)
      end
      log_start('#propagate_reference_ids')
      propagate_reference_ids
      files.each do |file|
        log("Removing #{file}")
        File.unlink(file)
      end
    rescue => e
      @log.fail(e)
    ensure
      log_end("TOTAL TIME: #{Time.delta_str(@start_at)}")
      log_close
    end
  end

  def repo_file_url(name)
    "/data/#{@resource_path}/publish_#{name}.tsv"
  end

  def exists?(name)
    url = URI.parse(repo_file_url(name))
    req = Net::HTTP.new(url.host, url.port)
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
    cols = @klass.connection.exec_query("DESCRIBE `#{@klass.table_name}`").rows.map(&:first)
    cols.delete('id') # We never load the PK, since it's auto_inc.
    q = ['LOAD DATA']
    q << 'LOCAL' unless Rails.env.development?
    q << "INFILE '#{@data_file}'"
    q << "INTO TABLE `#{@klass.table_name}`"
    q << "(#{cols.join(',')})"
    @klass.connection.execute(q.join(' '))
  end

  def propagate_ids
    @relationships[@klass].each do |field, source|
      next unless source
      # This is a little weird, so I'll explain. CURRENTLY, "field" is populated with the IDs FROM THE HARVEST DB. So
      # this code is joining the two tables via that harv_db_id, then re-setting the field with the REAL id (from THIS
      # DB).
      @klass.propagate_id(fk: field, other: "#{source.table_name}.harv_db_id",
                          set: field, with: 'id', resource_id: @resource.id)

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
    grab_file('traits')
    @data_file = @resource.meta_traits_file
    grab_file('metadata')
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
