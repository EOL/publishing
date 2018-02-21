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
    @calcluated_types = [Reference]
    @log = Publishing::PubLog.new(@resource)
  end

  def by_resource
    log_start('#remove_content')
    log_warn('All existing content will be destroyed for the resource. You have been warned.')
    @resource.remove_content
    files = []
    @relationships.each do |klass, propagations|
      log_start(klass)
      @klass = klass
      @resource_path = @resource.abbr.gsub(/\s+/, '_')
      @data_file = Rails.root.join('tmp', "#{@resource_path}_#{@klass.table_name}.tsv")
      if grab_file
        log_start('#import')
        import
        log_start('#propagate_ids')
        propagate_ids
        files << @data_file
      end
    end
    log_start('#create_new_pages')
    PageCreator.by_node_pks(node_pks, @log)
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
    log_end("Complete. Took: #{Time.delta_str(@start_at)}")
  end

  def grab_file
    url = "/data/#{@resource_path}/publish_#{@klass.table_name}.tsv"
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
    q = ['LOAD DATA LOCAL']
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
end
