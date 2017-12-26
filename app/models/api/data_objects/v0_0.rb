module Api
  module DataObjects
    class V0_0 < Api::Methods
      VERSION = '0.0'
      BRIEF_DESCRIPTION = Proc.new { "returns all metadata about a particular data object" }
      DESCRIPTION = Proc.new { 'data object api description' + '</p><p>' + 'image objects will contain two mediaurl elements' }
      TEMPLATE = '/api/pages_0_0'
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
        I18n.locale = params[:language] unless params[:language].blank?
        params[:details] = true
        data_object = Medium.find_by_guid(params[:id]) || Article.find_by_guid(params[:id]) || Link.find_by_guid(params[:id])
        raise ActiveRecord::RecordNotFound.new("Unknown data_object id \"#{params[:id]}\"") if data_object.blank?
        
        page_content = PageContent.where("content_id = ? and content_type = ? ", data_object.id, "Medium").first || PageContent.where("content_id = ? and content_type = ? ", data_object.id, "Article").first || PageContent.where("content_id = ? and content_type = ? ", data_object.id, "Link").first
        page_object = Page.search(page_content.page_id, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0]
        Api::Pages::V0_0.prepare_hash(page_object, params.merge({ :data_object => data_object, :details => true }))
      end
      
      def self.prepare_hash(data_object, params, page)
        return_hash = {}
        content_object = PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], data_object.id, data_object.class.name).first
        
        return_hash['identifier'] = data_object.guid
        return_hash['dataObjectVersionID'] = nil
        datatype = ''
        datasubtype = ''
        if data_object.class == Medium
          if data_object.map?
            datatype = 'Image'
            datasubtype = 'map'
          else
            datatype = data_object.subclass
            datasubtype = ''
          end
        elsif data_object.class == Link
          datatype = 'Article'
          datasubtype = 'Link'
        else
          datatype = data_object.class
          datasubtype = ''
        end
        return_hash['dataType'] = datatype
        return_hash['dataSubtype'] = datasubtype
        return_hash['vettedStatus'] = content_object.trust
        return_hash['dataRatings'] = ""
        return_hash['dataRating'] = ""

        if data_object.kind_of? Article
          return_hash['subject'] = data_object.sections.first.name
        end
        return return_hash unless params[:details] == true
        debugger
        if data_object && (data_object.kind_of? Medium) && data_object.is_image?
          if (info = ImageInfo.where("image_id = ?", data_object.id).first)
            size = info.original_size.split('x') unless info.original_size.blank?
            return_hash['height'] = size.last unless info.original_size.blank?
            return_hash['width'] = size.first unless info.original_size.blank?
            return_hash['crop_x'] = info.crop_x unless info.crop_x.blank?
            return_hash['crop_y'] = info.crop_y unless info.crop_y.blank?
            return_hash['crop_width'] = info.crop_w unless info.crop_w.blank?
            return_hash['crop_height'] = info.crop_w unless info.crop_w.blank? # We only suppose square crops right now!
          end
        end

        if (data_object.kind_of? Article) || (data_object.kind_of? Medium)
          return_hash['mimeType'] = data_object.mime_type unless data_object.mime_type.blank?
          return_hash['license'] = data_object.license.source_url unless data_object.license.blank?
          return_hash['rightsHolder'] = data_object.owner unless data_object.owner.blank?
          return_hash['bibliographicCitation'] = data_object.bibliographic_citation.body unless data_object.bibliographic_citation_id.blank?
          return_hash['description'] = data_object.description unless data_object.description.blank?
        end
        return_hash['created'] = data_object.created_at unless data_object.created_at.blank?
        return_hash['modified'] = data_object.updated_at unless data_object.updated_at.blank?
        return_hash['title'] = data_object.name unless data_object.name.blank?
        return_hash['language'] = data_object.language.group unless data_object.language.blank?
        return_hash['rights'] = data_object.rights_statement unless data_object.rights_statement.blank?
        
        return_hash['audience'] = []
         
        #duplicate source_url
        return_hash['source'] = data_object.source_url unless data_object.source_url.blank?
        return_hash['mediaURL'] = data_object.source_url unless data_object.source_url.blank?
        
        # return_hash['eolMediaURL'] = data_object. unless data_object.object_cache_url.blank?
        # return_hash['eolThumbnailURL'] = data_object.image_cache_path(data_object.object_cache_url, '98_68', :specified_content_host => Rails.configuration.asset_host) unless data_object.object_cache_url.blank?

        unless (data_object.kind_of? Link) || (data_object.location_id.nil?)
          return_hash['location'] = data_object.location.location
          unless data_object.location.latitude == 0 && data_object.location.longitude == 0 && data_object.location.altitude == 0
            return_hash['latitude'] = data_object.location.latitude
            return_hash['longitude'] = data_object.location.longitude
            return_hash['altitude'] = data_object.location.altitude
          end
        end
        
        return_hash['agents'] = []
        
        # links don't have attributions
        if (data_object.kind_of? Medium) || (data_object.kind_of? Article)
          data_object.attributions.each do |attribution|
            return_hash['agents'] << {
              'full_name' => attribution.value, #value ?
              'homepage'  => attribution.url,  #url ?
              'role'      => (attribution.role.name.downcase rescue nil)
            }
          end
        end
        
          # if data_object.content_partner
            # return_hash['agents'] << {
              # 'full_name' => data_object.content_partner.name,
              # 'homepage'  => data_object.content_partner.homepage,
              # 'role'      => (AgentRole.provider.label.downcase rescue nil)
            # }
          # end
        
        return_hash['references'] = []
        data_object.referents.each do |r|
          return_hash['references'] << r.body
          return_hash['references'].uniq!
        end
        return return_hash
      end

    end
  end
end