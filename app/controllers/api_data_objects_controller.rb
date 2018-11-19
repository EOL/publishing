class ApiDataObjectsController < LegacyApiController
  def index
    respond_to do |format|
      build_objects
      format.json { render json: @object }
      format.xml { render xml: @object.to_xml }
    end
  end

  def build_objects
    medium = if params[:id] =~ /\A\d+\Z/
      begin
        medium = Medium.where(id: params[:id]).includes(:language, :license).first
      rescue
        raise ActiveRecord::RecordNotFound.new("Unknown data_object id \"#{params[:id]}\"")
      end
    else
      Medium.find_by_guid(params[:id])
    end
    # TODO: handle non-images here...
    @object = {
      identifier: medium.guid,
      dataObjectVersionID: medium.id,
      dataType: 'http://purl.org/dc/dcmitype/StillImage',
      dataSubtype: medium.format,
      vettedStatus: '', # TODO
      dataRatings: '', # TODO
      dataRating: '2.5', # TODO
      mimeType: 'image/jpeg'
    }
    add_details_to_data_object(@object, medium)
    page = Page.where(id: medium.page_id).
      includes(native_node: :scientific_names, nodes: { references: :referent }).first

    @object = {
      taxon: {
        identifier: page.id,
        scientificName: page.native_node.preferred_scientific_name.verbatim,
        richness_score: page.page_richness,
        dataObjects: [@object]
      }
    }
    add_taxonomy_to_page(@object, page)
    @object
  end
end
