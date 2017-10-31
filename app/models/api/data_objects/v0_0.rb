module Api
  module DataObjects
    class V0_0 < Api::Methods
      VERSION = '0.0'
      BRIEF_DESCRIPTION = Proc.new { "returns all metadata about a particular data object" }
      DESCRIPTION = Proc.new { 'data object api description' + '</p><p>' + 'image objects will contain two mediaurl elements' }
      TEMPLATE = '/api/pages_0_4'
      PARAMETERS = Proc.new {
        [
          Api::DocumentationParameter.new(
          :name => 'id',
          :type => String,
          :required => true,
          :test_value => (Medium.find_by_guid('3e2749d04f955628be390d9c9e0dc0a4') || Medium.last).guid,
          :notes =>  'guid of data object'),
          Api::DocumentationParameter.new(
          :name => 'taxonomy',
          :type => 'Boolean',
          :default => true,
          :test_value => true,
          :notes =>  'return any taxonomy details from different hierarchy providers'),
          Api::DocumentationParameter.new(
          :name => 'cache_ttl',
          :type => Integer,
          :notes =>  'api cache time to live parameter'),
          Api::DocumentationParameter.new(
          :name => "language",
          :type => String,
          :values => ["en", "fr"] ,
          :default => "en",
          :notes => "choose language")
        ] }
        
      def self.call(params={})
        validate_and_normalize_input_parameters(params)
        # I18n.locale = params[:language] unless params[:language].blank?
        params[:details] = true
        data_object = Medium.find_by_guid(params[:id]) || Article.find_by_guid(params[:id])
        raise ActiveRecord::RecordNotFound.new("Unknown data_object id \"#{params[:id]}\"") if data_object.blank?
        
        page_content = PageContent.where("content_id = ? and content_type = ? ", data_object.id, "Medium").first || PageContent.where("content_id = ? and content_type = ? ", data_object.id, "Article").first
        page_object = Page.search(page_content.page_id, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0]
            # latest_version = data_object.latest_version_in_same_language(:check_only_published => true)
            # if latest_version.blank?
              # latest_version = data_object.latest_version_in_same_language(:check_only_published => false)
            # end
            # data_object = DataObject.find_by_id(latest_version.id)
          # all_visible_published_taxa = data_object.uncached_data_object_taxa(published: true,
            # visibility_id: Visibility.get_visible.id, vetted_id: [ Vetted.trusted.id, Vetted.unknown.id ])
          # taxon_concept = all_visible_published_taxa.empty? ?
            # nil : DataObjectTaxon.default_sort(all_visible_published_taxa).first.taxon_concept
         Api::Pages::V0_0.prepare_hash(page_object, params.merge({ :data_object => data_object, :details => true }))
      end
      
      def self.prepare_hash(data_object, params, page)
        return_hash = {}
        content_object = PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], data_object.id, data_object.class.name).first
        
        return_hash['identifier'] = data_object.guid
        return_hash['dataObjectVersionID'] = data_object.id
        # return_hash['dataType'] = data_object.data_type.schema_value
        # return_hash['dataSubtype'] = data_object.data_subtype.label rescue ''
        return_hash['vettedStatus'] = content_object.trust
        # return_hash['dataRatings'] = data_object.rating_summary
        # return_hash['dataRating'] = data_object.data_rating

        # if data_object.is_text?
        # if data_object.created_by_user? && !data_object.toc_items.blank?
        # return_hash['subject']            = data_object.toc_items[0].info_items[0].schema_value unless data_object.toc_items[0].info_items.blank?
        # else
        # return_hash['subject']            = data_object.info_items[0].schema_value unless data_object.info_items.blank?
        # end
        # end
        return return_hash unless params[:details] == true

        if data_object && (data_object.kind_of? Medium) && data_object.is_image?
        # image_info= data_object.image_info
        # return_hash['height']               = image_info.height unless image_info.height.blank?
        # return_hash['width']                = image_info.width unless image_info.width.blank?
        # return_hash['crop_x']               = image_info.crop_x_pct * return_hash['width'] / 100.0  unless image_info.crop_x_pct.blank? || return_hash['width'].blank?
        # return_hash['crop_y']               = image_info.crop_y_pct * return_hash['height'] / 100.0  unless image_info.crop_y_pct.blank? || return_hash['height'].blank?
        # return_hash['crop_height']          = image_info.crop_height_pct * return_hash['height'] / 100.0  unless image_info.crop_height_pct.blank? || return_hash['height'].blank?
        # return_hash['crop_width'] = image_info.crop_width_pct * return_hash['width'] / 100.0 unless image_info.crop_width_pct.blank? || return_hash['width'].blank?
        end

        # return_hash['mimeType'] = data_object.mime_type.label unless data_object.mime_type.blank?
        return_hash['created']                = data_object.created_at unless data_object.created_at.blank?
        return_hash['modified']               = data_object.updated_at unless data_object.updated_at.blank?
        return_hash['title']                  = data_object.name unless data_object.name.blank?
        return_hash['language']               = data_object.language.group unless data_object.language.blank?
        return_hash['license']                = data_object.license.source_url unless data_object.license.blank?
        return_hash['rights']                 = data_object.rights_statement unless data_object.rights_statement.blank?
        return_hash['rightsHolder']           = data_object.owner unless data_object.owner.blank?
        return_hash['bibliographicCitation'] = data_object.bibliographic_citation_id.body unless data_object.bibliographic_citation_id.blank?
        # return_hash['audience'] = data_object.audiences.collect{ |a| a.label }

        return_hash['source']                 = data_object.source_url unless data_object.source_url.blank?
        return_hash['description']            = data_object.description unless data_object.description.blank?
        # return_hash['mediaURL']               = data_object.source_page_url unless data_object.source_page_url.blank?
        # return_hash['eolMediaURL']          = DataObject.image_cache_path(data_object.object_cache_url, :orig, :specified_content_host => Rails.configuration.asset_host) unless data_object.object_cache_url.blank?
        # return_hash['eolThumbnailURL'] = DataObject.image_cache_path(data_object.object_cache_url, '98_68', :specified_content_host => Rails.configuration.asset_host) unless data_object.object_cache_url.blank?

        unless data_object.location_id.nil?
          return_hash['location'] = data_object.location_id.location
          unless data_object.location_id.latitude == 0 && data_object.location_id.longitude == 0 && data_object.location_id.altitude == 0
            return_hash['latitude'] = data_object.location_id.latitude
            return_hash['longitude'] = data_object.location_id.longitude
            return_hash['altitude'] = data_object.location_id.altitude
          end
        end
        return return_hash
      end

    end
  end
end