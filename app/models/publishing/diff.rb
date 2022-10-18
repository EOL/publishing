class Publishing
  class Diff
    require 'net/http'
    include Publishing::Common
    attr_accessor :data_file, :log

    def self.by_resource(resource)
      differ = new(resource)
      differ.by_resource
    end

    def initialize(resource, log = nil)
      @start_at = Time.now
      @resource = resource
      # NOTE: this is likely to get overridden once we create a new log, but nice to have in case we need it:
      @log = log # Okay if it's nil.
      @repo = create_server_connection
      @files = []
      @can_clean_up = true
    end

    def by_resource
      set_relationships
      abort_if_already_running
      new_log
      unless @resource.nodes.count.zero?
        begin
          @resource.remove_non_trait_content
          # Re-grabbing the log shouldn't really be needed, but apparently it's a thing ...after removing traits?!
          @log = Publishing::PubLog.new(@resource, use_existing_log: true)
        rescue => e
          @log = Publishing::PubLog.new(@resource, use_existing_log: true)
          @log.fail_on_error(e)
          raise e
        end
        @log.warn('All existing content has been destroyed for the resource.')
      end
      begin
        unless @repo.exists?('nodes.tsv')
          raise("#{@repo.file_url('nodes.tsv')} does not exist! Are you sure the resource has successfully finished harvesting?")
        end
        @relationships.each_key { |klass| import_and_prop_ids(klass) }
        @log.start('restoring vernacular preferences...')
        VernacularPreference.restore_for_resource(@resource.id, @log)
        # You have to create pages BEFORE you slurp traits, because now it needs the scientific names from the page
        # objects.
        @log.start('PageCreator')
        PageCreator.by_node_pks(node_pks, @log, skip_reindex: true)
        if page_contents_required?
          @log.start('MediaContentCreator')
          MediaContentCreator.by_resource(@resource, log: @log)
        end
        publish_traits_with_cleanup
        @log.start('Resource#fix_native_nodes')
        @resource.fix_native_nodes
        @log.start('TraitBank::Denormalizer.update_resource_vernaculars')
        TraitBank::Denormalizer.update_resource_vernaculars(@resource)
        propagate_reference_ids
        clean_up
        if page_contents_required?
          @log.start('#fix_missing_icons (just to be safe)')
          Page.fix_missing_icons
        end
        Publishing::DynamicWorkingHierarchy.update(@resource, @log) if @resource.dwh?
      rescue => e
        clean_up
        @log.fail_on_error(e)
      ensure
        @log.end("TOTAL TIME: #{Time.delta_str(@start_at)}")
        @log.close
        ImportLog.all_clear!
      end
    end

    def traits_by_resource
      abort_if_already_running
      @log = Publishing::PubLog.new(@resource, use_existing_log: true)
      @repo = create_server_connection
      @can_clean_up = true
      begin
        publish_traits_with_cleanup
      rescue => e
        clean_up
        @log.fail_on_error(e)
      ensure
        @log.end("TOTAL TIME: #{Time.delta_str(@start_at)}")
        @log.close
        ImportLog.all_clear!
      end
    end

    def publish_traits_with_cleanup
      @log.start('#publish_traits = TraitBank::Slurp.load_resource_from_repo')
      begin
        # YOU WILL HAVE TO WRITE THIS ARGH
      rescue => e
        backtrace = [e.backtrace[0]] + e.backtrace.grep(/\bapp\b/)[1..5]
        @log.warn("Trait Publishing failed: #{e.message} FROM #{backtrace.join(' << ')}")
        @can_clean_up = false
      end
      clean_up
    end

    def import_and_prop_ids(klass)
      @klass = klass
      @log.start("#import_and_prop_ids #{@klass}")
      @data_file = Rails.root.join('tmp', "#{@resource.path}_#{@klass.table_name}.tsv")
      if grab_file("#{@klass.table_name}.tsv")
        import
        propagate_ids
        @files << @data_file
      end
    end

    def import
      @log.start("#import #{@klass}")
      cols = @klass.column_names
      cols.delete('id') # We never load the PK, since it's auto_inc.

      q = ['LOAD DATA']
      q << %{LOCAL INFILE '#{@data_file}' INTO TABLE `#{@klass.table_name}` }
      q << %{CHARACTER SET utf8mb4 FIELDS OPTIONALLY ENCLOSED BY '"' }
      q << "(#{cols.join(',')})"

      begin
        before_db_count = @klass.where(resource_id: @resource.id).count
        file_count = `wc #{@data_file}`.split.first.to_i
        @klass.connection.execute(q.join(' '))
        after_db_count = @klass.where(resource_id: @resource.id).count - before_db_count
        # All a fencepost error here for a newline at the end of the file:
        if (file_count != after_db_count) && (file_count != after_db_count + 1)
          @log.warn("INCORRECT NUMBER OF ROWS DURING IMPORT OF #{@klass.name.pluralize.downcase}: "\
            "got #{after_db_count}, expected #{file_count} (from #{@data_file})")
        end
      rescue => e
        puts 'FAILED TO LOAD DATA. NOTE that it\'s possible you need to A) In Mysql,'
        puts 'GRANT FILE ON *.* TO your_user@localhost IDENTIFIED BY "your_password";'
        puts '...and B) add "local_infile=true" to your database.yml config for this to work.'
        raise e
      end
    end
  end
end
