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
        create_set_variables
        handle_diffs
        denormalize_models
        clean_up
      rescue => e
        clean_up
        @log.fail_on_error(e)
      ensure
        @log.end("TOTAL TIME: #{Time.delta_str(@start_at)}")
        @log.close
        ImportLog.all_clear!
      end
    end

    def create_set_variables
      @affected_pages = Set.new
      @affected_media_pages = Set.new
      @new_page_ids = Set.new
      @new_media_ids = Set.new
      @new_article_ids = Set.new
    end

    def handle_diffs
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
        create_models(diff_handler)
        update_models(diff_handler)
        delete_models(diff_handler)
        propagate_ids # NOTE: uses @klass
        @files << @data_file
        Page.fix_missing_native_nodes(Page.where(page_id: @affected_pages.to_a))
        PageIcon.fix_by_page_id(@affected_media_pages.to_a)
        TraitBank::Denormalizer.update_attributes_by_page_id(@affected_pages.to_a)
      end
    end

    def create_models(diff_handler)
      diff_handler.created.each do |data|
        attributes = @klass.column_names.zip(data)
        model = @klass.create(attributes)
        log_page(attributes)
        if @klass == Node
          @new_page_ids << attributes['page_id'] unless Page.exist?(id: attributes['page_id'])
        elsif @klass == Medium
          @new_media_ids << model.id
        elsif @klass == Article
          @new_article_ids << model.id
        end
      end
    end

    def update_models(diff_handler)
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
    end

    def delete_models(diff_handler)
      diff_handler.deleted.each do |data|
        attributes = @klass.column_names.zip(data)
        attributes.delete('id')
        model = @klass.find_by(attributes)
        raise "Unable to delete, no model found: #{attributes}" if model.nil?
        model.destroy
        log_page(data)
      end
    end

    def log_page(data)
      return unless @check_pages
      @affected_pages << data[@check_pages]
      @affected_media_pages << data[@check_pages] if @klass == Medium
    end

    def denormalize_models
      create_new_pages
      content_creator = MediaContentCreator.new(resource, log: @log)
      content_creator.by_media_ids(@new_media_ids)
      content_creator.by_media_ids(@new_article_ids)
      @log.start('restoring vernacular preferences...')
      VernacularPreference.restore_for_resource(@resource.id, @log)
      propagate_reference_ids
      return unless @resource.dwh?
      @log.start('Dynamic Working Hierarchy! Updating...')
      Publishing::DynamicWorkingHierarchy.update(@resource, @log)
    end

    def create_new_pages
      @new_page_ids.each do |page_id|
        next if Page.exists?(id: page_id)
        next unless Node.exists?(page_id: page_id)
        native_nodes = Node.where(page_id: page_id).order(:id)
        page = Page.create!(id: page_id, native_node_id: native_node.first.id, nodes_count: native_nodes.size)
        page.reindex
        Node.counter_culture_fix_counts start: native_nodes.first.id, finish: native_nodes.last.id
      end
    end
  end
end
