class Publishing::Fast
  require 'net/http'
  attr_accessor :data_file, :log

  def self.by_resource(resource)
    publr = new(resource)
    publr.by_resource
  end

  # e.g.: nohup rails r "Publishing::Fast.update_attribute_by_resource(Resource.find(589), ScientificName, :dataset_name)" > dwh_datasets.log 2>&1 &
  def self.update_attribute_by_resource(resource, klass, field)
    publr = new(resource)
    publr.update_attribute(klass, field)
  end

  # e.g.: Publishing::Fast.load_local_file(Resource.find(123), NodeAncestor, '/some/path/to/tmp/DWH_node_ancestors.tsv')
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
    @repo = Repository.new(resource, log)
    @log = log # Okay if it's nil.
    @files = []
  end

  # NOTE: this does NOT work for traits. Don't try. You'll need to make a different method for that.
  def update_attribute(klass, field)
    require 'csv'
    abort_if_already_running
    @klass = klass
    # NOTE: Minus one for the id, which is NEVER in the file but is ALWAYS the first column in the table:
    pos = @klass.column_names.index(field.to_s) - 1
    new_log
    begin
      plural = @klass.table_name
      unless @repo.exists?("#{plural}.tsv")
        raise("#{@repo.file_url("#{plural}.tsv")} does not exist! Are you sure the resource has successfully finished harvesting?")
      end
      log_start("Updating attribute #{field} (#{pos}) for #{plural}")
      @data_file = Rails.root.join('tmp', "#{@resource.path}_#{plural}.tsv")
      if grab_file("#{plural}.tsv")
        all_data = CSV.read(@data_file, col_sep: "\t")
        pk_pos = @klass.column_names.index('resource_pk') || @klass.column_names.index('node_resource_pk')
        pk_pos -= 1 # For 0-index
        all_data.in_groups_of(2000, false) do |lines|
          pk = :resource_pk
          pks = lines.map { |l| l[pk_pos] }
          instances =
            begin
              @klass.where(resource_id: @resource.id, resource_pk: pks).load
            rescue ActiveRecord::StatementInvalid
              pk = :node_resource_pk
              @klass.where(resource_id: @resource.id, node_resource_pk: pks)
            end
          log_warn("#{instances.size} instances by resource_pk")
          keyed_instances = instances.group_by(&pk)
          log_warn("#{keyed_instances.keys.size} groups of keyed_instances")
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
          log_warn("#{changes.size} changes...")
          @klass.import(changes, on_duplicate_key_update: [field])
        end
        @files << @data_file
      else
        log_warn("COULDN'T FIND #{plural}.tsv !")
      end
    rescue => e
      @log.fail(e)
      raise e
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
      BibliographicCitation => { },
      Identifier => { node_id: Node },
      ScientificName => { node_id: Node },
      NodeAncestor => { node_id: Node, ancestor_id: Node },
      Vernacular => { node_id: Node },
      # Yes, really, there is no link to nodes or pages on Article or Medium; these are managed with PageContent.
      Article => { bibliographic_citation_id: BibliographicCitation },
      Medium => { bibliographic_citation_id: BibliographicCitation },
      Attribution => { content_id: [Medium, Article] }, # Polymorphic implied with array.
      ImageInfo => { medium_id: Medium },
      Reference => { referent_id: Referent }, # The polymorphic relationship is handled specially.
      ContentSection => { content_id: [Article] } # NOTE: at the moment, only articles have sections...
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
      unless @repo.exists?('nodes.tsv')
        raise("#{@repo.file_url('nodes.tsv')} does not exist! Are you sure the resource has successfully finished harvesting?")
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
      VernacularPreference.restore_for_resource(@resource.id, @log)
      # You have to create pages BEFORE you slurp traits, because now it needs the scientific names from the page
      # objects.
      log_start('PageCreator')
      PageCreator.by_node_pks(node_pks, @log, skip_reindex: true)
      if page_contents_required?
        log_start('MediaContentCreator')
        MediaContentCreator.by_resource(@resource, log: @log)
      end
      log_start('Remove traits')
      TraitBank::Admin.remove_for_resource(@resource)
      log_start('#publish_traits')
      can_clean_up = true
      begin
        publish_traits
      rescue => e
        log_warn("Trait Publishing failed: #{e.message} FROM #{e.backtrace[0..5].join(' FROM ')}")
        can_clean_up = false
      end
      log_start('#fix_native_nodes')
      @resource.fix_native_nodes
      propagate_reference_ids
      clean_up if can_clean_up
      if page_contents_required?
        log_start('#fix_missing_icons (just to be safe)')
        Page.fix_missing_icons
      end
    rescue => e
      clean_up
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

  def grab_file(name)
    open(@data_file, 'wb') { |file| file.write(@repo.file(name)) }
  end

  def import
    cols = @klass.column_names
    cols.delete('id') # We never load the PK, since it's auto_inc.
    q = ['LOAD DATA']
    # NOTE: "LOCAL" is a strange directive; you only use it when you are REMOTE. ...The intention being, you're telling
    # the remote server "the file I'm talking about is local to me." Confusing at best. I don't like it.
    q << 'LOCAL' unless @repo.is_on_this_host?
    q << %{INFILE '#{@data_file}' INTO TABLE `#{@klass.table_name}` FIELDS OPTIONALLY ENCLOSED BY '"'}
    q << "(#{cols.join(',')})"
    begin
      before_db_count = @klass.where(resource_id: @resource.id).count
      file_count = `wc #{@data_file}`.split.first.to_i
      @klass.connection.execute(q.join(' '))
      after_db_count = @klass.where(resource_id: @resource.id).count - before_db_count
      if file_count != after_db_count
      log_warn("INCORRECT NUMBER OF ROWS DURING IMPORT OF #{@klass.name.pluralize.downcase}: got #{after_db_count}, "\
        "expected #{file_count} (from #{@data_file})")
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
    log_start('#propagate_reference_ids')
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
          inner_clauses = clauses.dup
          upper = min + page_size - 1
          inner_clauses << "WHERE t.id >= #{min} AND t.id <= #{upper}"
          ActiveRecord::Base.connection.execute(inner_clauses.join(' '))
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
    TraitBank::Slurp.load_resource_from_repo(@resource)
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
