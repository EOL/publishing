class Publishing
  module Common
    require 'net/http'
    attr_accessor :data_file, :log

    def create_server_connection
      ContentServerConnection.new(@resource, @log)
    end

    def set_relationships
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
    end

    def abort_if_already_running
      if (info = ImportLog.already_running?)
        @resource.log("ABORTED: #{info}")
        raise(info)
      end
    end

    def new_log
      @log ||= Publishing::PubLog.new(@resource) # you MIGHT want @resource.import_logs.last
      @repo = create_server_connection
      @log
    end

    def clean_up
      return(nil) unless @can_clean_up
      @files.each do |file|
        if File.exist?(file)
          @log.info("Removing #{file}")
          File.unlink(file)
        else
          @log.info("Skipping removal of #{file} ... file does not exist")
        end
      end
      @can_clean_up = false
    end

    def grab_file(name)
      @log.start("#grab_file #{name}")
      if repo_file = @repo.file(name)
        open(@data_file, 'wb') { |file| file.write(repo_file) }
      else
        return false
      end
    end

    def propagate_ids
      @log.start("#propagate_ids #{@klass}")
      @relationships[@klass].each do |field, sources|
        next unless sources
        Array(sources).each do |source| # Array implies polymorphic relationship
          # This is a little weird, so I'll explain. CURRENTLY, "field" is populated with the IDs FROM THE HARVEST DB.
          # So this code is joining the two tables via that harv_db_id, then re-setting the field with the REAL id (from
          # THIS DB).
          @klass.propagate_id(fk: field, other: "#{source.table_name}.harv_db_id",
                              set: field, with: 'id', resource_id: @resource.id)
        end
      end
    end

    def propagate_reference_ids
      return nil if Reference.where(resource_id: @resource.id).count.zero?
      @log.start('#propagate_reference_ids')
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

    def page_contents_required?
      Medium.where(resource_id: @resource.id).any? || Article.where(resource_id: @resource.id).any?
    end

    def node_pks
      Node.where(resource_id: @resource.id).pluck(:resource_pk)
    end
  end
end
