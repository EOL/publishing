class ApiCollectionsController < LegacyApiController
  def index
    respond_to do |format|
      results = get_results
      format.json { render json: results }
      format.xml { render xml: results.to_xml }
    end
  end

  private

  def get_results
    @page = (params[:page] || 1).to_i
    @per_page = (params[:per_page] || 50).to_i
    @collection = Collection.where(id: params[:id]).includes(:collection_associations).first
    raise "Not found" if @collection.nil?
    @pages = CollectedPage.where(collection_id: @collection.id)
    # These are the old V2 sorts and what we're forced to implement for V3:
    build_pages
    build_return_hash
    @pages.each do |page|
      add_page(page)
      add_images(page)
    end
    @return_hash
  end

  def convert_sort
    @convert_sort ||= {
          'recently_added' => :position,
          'oldest' => :position,
          'alphabetical' => :sci_name,
          'reverse_alphabetical' => :sci_name_rev,
          'richness' => :position,
          'rating' => :position,
          'sort_field' => :sort_field,
          'reverse_sort_field' => :sort_field_rev
        }
  end

  def build_pages
    sort_type = (convert_sort.key?(params[:sort_by]) ? convert_sort[params[:sort_by]] : @collection.default_sort).dup
    sort_type ||= "position"
    rev = sort_type.to_s.sub(/_rev$/, '')
    case sort_type
    when "sci_name"
      @pages = @pages.joins(page: [:medium, { native_node: :rank }]).
        order("nodes.canonical_form#{rev ? " DESC" : ""}")
    when "sort_field"
      @pages = @pages.
        includes(:collection, :media, page: [:medium, :preferred_vernaculars, { native_node: :rank }]).
        # NOTE: this ugly sort handles "if it's empty, put it at the end"
        order("if(annotation = '' or annotation is null,1,0),annotation#{rev ? " DESC" : ""}")
    when "hierarchy"
      @pages = @pages.joins(page: { native_node: :rank }).
        order("nodes.depth#{rev ? " DESC" : ""}, nodes.canonical_form")
    else
      @pages = @pages.
        includes(:collection, :media, page: [:medium, :preferred_vernaculars, { native_node: :rank }]).
        order("position")
    end
    @pages = @pages.by_page(@page).per(@per_page)
  end

  def add_page(page)
    @return_hash[:collection_items] << {
      'name' => page.page.name,
      'object_type' => 'TaxonConcept', # Remember, this is V2 terminology
      'object_id' => page.page_id,
      'title' => page.page.canonical,
      'created' => page.created_at,
      'updated' => page.updated_at,
      'annotation' => page.annotation,
      'sort_field' => page.annotation
    }
  end

  def add_images(page)
    if page.collected_pages_media.any?
      page.collected_pages_media.includes(:medium).each do |c_medium|
        medium = c_medium.medium
        next if medium.nil?
        data_object = {
          'name' => medium.name,
          'object_type' => 'DataObject', # Remember, this is V2 terminology
          'object_id' => medium.id,
          'annotation' => '',
          'sort_field' => '',
          'object_guid' => medium.guid
        }
        add_details_to_data_object(data_object, medium)
        @return_hash[:collection_items] << data_object
      end
    end
  end

  def build_return_hash
    @return_hash = {
      name: @collection.name,
      description: @collection.description,
      created: @collection.created_at,
      modified: @collection.updated_at,
      total_items: @collection.collected_pages.count,
      collection_items: []
    }
  end
end
