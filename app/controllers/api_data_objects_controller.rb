class ApiDataObjectsController < LegacyApiController
  def index
    respond_to do |format|
      build_objects
      format.json { render json: @object }
      format.xml { render xml: @object.to_xml }
    end
  end

  def medium_or_article(attrs)
    if Medium.exists?(attrs)
      Medium.where(attrs)
    elsif Article.exists?(attrs)
      Article.where(attrs)
    else
      nil
    end
  end

  def build_objects
    @object = {}
    content =
      if params[:id] =~ /\A\d+\Z/
        medium_or_article(id: params[:id])
      else
        medium_or_article(guid: params[:id])
      end
    if content.nil?
      raise ActiveRecord::RecordNotFound.new("Unknown data_object id \"#{params[:id]}\"")
    end
    content = content.includes(:language, :license).first
    # TODO: handle non-images here...
    type = 'http://purl.org/dc/dcmitype/StillImage'
    mime = 'image/jpeg'
    if content.is_a?(Article)
      type = 'http://purl.org/dc/dcmitype/Text'
      mime = 'text/html' # really, this could be text/plain, but we're not sure. I think this is safer.
    end
    format = content.respond_to?(:format) ? content.format : ''
    @object = {
      identifier: content.guid,
      dataObjectVersionID: content.id,
      dataType: type,
      dataSubtype: format,
      vettedStatus: 'Trusted',
      dataRatings: '', # TODO
      dataRating: '2.5', # Faked per Yan Wang's suggestion.
      mimeType: mime
    }
    add_details_to_data_object(@object, content)
    page = Page.where(id: content.page_id).
      includes(native_node: :scientific_names, nodes: { references: :referent }).first

    @object = {
      taxon: {
        identifier: page.id,
        scientificName: page.safe_native_node.preferred_scientific_name&.verbatim,
        richness_score: page.page_richness,
        dataObjects: [@object]
      }
    }
    add_taxonomy_to_page(@object, page)
    @object
  end
end
