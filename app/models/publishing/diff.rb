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
        @repo.diffs.each do |diff_uri|
          # filename will look like publish_[table]_{harvest_at}.diff
          diff_filename = diff_uri.sub(%r{^.*\/}, '')
          diff_path = "#{@resource.path}/#{diff_filename}"
          @repo.grab_file(diff_uri, diff_path)
          @klass = diff_filename.sub(/^publish_/, '').sub(/_\d+.tsv$/, '')
          @data_file = Rails.root.join('tmp', "#{@resource.path}_#{@klass.table_name}.diff")
          File.open(diff_filename, 'r').each_line do |line|
            # TODO: create new
            # TODO: edit existing
            # TODO: remove deleted
            # TODO: log affected pages
            propagate_ids # NOTE: uses @klass
            @files << @data_file
          end
          # TODO: Check that the native_nodes haven't been removed on pages affected
          # TODO: fix page icons on affected pages
          # TODO: re-write

          # TODO: you need to create pages when ingesting nodes and the page is missing
          # TODO: You'll need a media content creator to run on new media...
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
  end
end
