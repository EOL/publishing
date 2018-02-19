class Publishing::Fast
  require 'net/http'

  def initialize(resource)
    @resource = resource
    @repo_site = Rails.configuration.secrets.repository['url']
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
      References => { referent_id: Referent } # The polymorphic relationship is handled specially.
    }
    # @ids = {}
    @calcluated_types = [Reference]
    @log = Publishing::PubLog.new(@resource)
  end

  def by_resource
    @resource.remove_content # CAUTION!!! All existing content will be destroyed for the resource. You have been warned.
    @relationships.each do |klass, propagations|
      @klass = klass
      @resource_path = @resource.abbr.gsub(/\s+/, '_')
      # TODO: check whether the file exists!
      @data_file = Rails.root.join('tmp', "#{resource_path}_#{@klass.table_name}.tsv")
      grab_file
      import
      propagate_ids
      PageCreator.create_new_pages(node_pks, @log)
      MediaContentCreator.by_resource(@resource, @log) if page_contents_required?
      propagate_reference_ids
    end
    # TODO: remove temp files...
  end

  def grab_file
    url = "/data/#{resource_path}/publish_#{@klass.table_name}.tsv"
    Net::HTTP.start(@repo_site) do |http|
      resp = http.get(url)
      open(data_file, 'wb') { |file| file.write(resp.body) }
    end
  end

  def import
    q = ['LOAD DATA']
    q << 'LOCAL' unless Rails.env.development?
    q << "INFILE '#{@data_file}'"
    # q << 'REPLACE ' unless cols
    q << "INTO TABLE `#{@klass.table_name}`"
    # q << "(#{cols.join(',')})" if cols
    @klass.connection.execute(q.join(' '))
  end

  def propagate_ids
    @relationships[@klass].each do |field, source|
      # learn_ids(source) unless @ids.key?(source)
      # This is a little weird, so I'll explain. CURRENTLY, "field" is populated with the IDs FROM THE HARVEST DB. So
      # this code is joining the two tables via that harv_db_id, then re-setting the field with the REAL id (from THIS
      # DB).
      @klass.propagate_id(fk: field, other: "#{@klass.table_name}.harv_db_id",
                          set: field, with: 'id', resource_id: @resource.id)

    end
  end

  def propagate_reference_ids
    # TODO: all of the things that CAN have references .each do |other|
      update_clause  = "UPDATE `references` t JOIN `#{other}` o ON (t.parent_id = o.harv_db_id"
      update_clause += " AND t.resource_id = #{@resource.id} AND t.parent_type = #{other})" # <-- TODO: check that format
      set_clause = "SET t.parent_id = o.id"

      # TODO: we should probably paginate that, argh.

    # Reference.propagate_id(fk: field, other: "#{@klass.table_name}.harv_db_id",
    #                     set: field, with: 'id', resource_id: @resource.id)

  end

  # def learn_ids(klass)
  #   @ids[klass] = {}
  #   klass.selects('id, harv_db_id').find_each do |object|
  #     @ids[klass][object.harv_db_id] = object.id
  #   end
  # end

  def page_contents_required?
    Medium.where(resource_id: @resource.id).any? || Article.where(resource_id: @resource.id).any?
  end

  def node_pks
    Node.where(resource_id: @resource.id).pluck(:resource_pk)
  end
end
