class Publishing
  class Diff
    require 'net/http'
    include Publishing::Common
    attr_accessor :data_file, :log

    def self.by_resource(resource)
      differ = new(resource)
      differ.by_resource
    end

    def by_resource
      set_relationships
      abort_if_already_running
      @log = Publishing::PubLog.new(@resource, use_existing_log: true)
      connect_to_repo
      begin
        @affected_pages = Set.new
        @repo.diffs.each do |diff_uri|
          @check_pages = @klass.column_names.include?('page_id') ? @klass.column_names.index('page_id') : false
          # filename will look like publish_[table]_{harvest_at}.diff
          diff_filename = diff_uri.sub(%r{^.*\/}, '')
          diff_path = "#{@resource.path}/#{diff_filename}"
          @repo.grab_file(diff_uri, diff_path)
          @klass = diff_filename.sub(/^publish_/, '').sub(/_\d+.tsv$/, '')
          @data_file = Rails.root.join('tmp', "#{@resource.path}_#{@klass.table_name}.diff")
          diff_handler = Publishing::DiffHandler.new(diff_filename)
          diff_handler.parse
          diff_handler.created.each do |data|
            @klass.create(@klass.column_names.zip(data))
            log_page(data)
            if @klass == Node
              # TODO: you need to create pages when ingesting nodes and the page is missing
            elsif @klass == Medium
              # TODO: You'll need a media content creator to run on new media...
            end
          end
          diff_handler.updated_from.each_with_index do |data, i|
            attributes = @klass.column_names.zip(data)
            to_attributes = @klass.column_names.zip(diff_handler.updated_to[i])
            attributes.delete('id')
            to_attributes.delete('id')
            model = @klass.find_by(attributes)
            raise "Unable to update, no model found: #{attributes}" if model.nil?
            model.update!(to_attributes)
            log_page(data)
          end
          diff_handler.deleted.each do |data|
            attributes = @klass.column_names.zip(data)
            attributes.delete('id')
            model = @klass.find_by(attributes)
            raise "Unable to delete, no model found: #{attributes}" if model.nil?
            model.destroy
            log_page(data)
            if @klass == Node
              # TODO: Check that the native_nodes haven't been removed on pages affected
            elsif @klass == Medium
              # TODO: fix page icons on affected pages
            end
          end
          propagate_ids # NOTE: uses @klass
          @files << @data_file
          # TODO: TraitBank::Denormalizer.update_resource_vernaculars(@resource) on affected pages
        end
        @log.start('restoring vernacular preferences...')
        VernacularPreference.restore_for_resource(@resource.id, @log)
        propagate_reference_ids
        clean_up
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

    def log_page(data)
      @affected_pages << data[@check_pages] if @check_pages
    end
  end
end
