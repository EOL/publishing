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
        medium = Medium.find(params[:id])
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
      dataRating: '', # TODO
      mimeType: 'image/jpeg'
    }
    add_details_to_data_object(@object, medium)
  end
end
