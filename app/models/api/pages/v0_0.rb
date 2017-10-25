module Api
  module Pages
    class V0_0 < Api::Methods
      Searchkick
      DEFAULT_OBJECTS_NUMBER=1
      VERSION='0.0'
      BRIEF_DESCRIPTION= Proc.new {"brife description" }
      DESCRIPTION= Proc.new {"API Pages" }
      PARAMETERS = Proc.new {
        [
          Api::DocumentationParameter.new(
          :name => 'batch',
          :type => 'Boolean',
          :default => false,
          :test_value => false,
          :notes => "need batch or not" ),
          Api::DocumentationParameter.new(
          :name => 'id',
          :type => String,
          :required => true,
          :test_value => (Page.find_by_id(328598) || Page.last).id ),
          Api::DocumentationParameter.new(
          :name => 'images_per_page',
          :type => Integer,
          :values => (0..75),
          :default => 1,
          :test_value => 1,
          :notes => "number of images per page" ),
          Api::DocumentationParameter.new(
          :name => 'images_page',
          :type => Integer,
          :default => 1,
          :test_value => 1,
          :notes => "select specified page for images" ),
          Api::DocumentationParameter.new(
          :name => 'videos_per_page',
          :type => Integer,
          :values => (0..75),
          :test_value => 1,
          :notes => "number of videos per page"  ),
          Api::DocumentationParameter.new(
          :name => 'videos_page',
          :type => Integer,
          :default => 1,
          :test_value => 1,
          :notes => "select specified page for videos" ),
          Api::DocumentationParameter.new(
          :name => 'sounds_per_page',
          :type => Integer,
          :values => (0..75),
          :test_value => 1,
          :notes => "number of sounds per page"  ),
          Api::DocumentationParameter.new(
          :name => 'sounds_page',
          :type => Integer,
          :default => 1,
          :test_value => 1,
          :notes => "select specified page for sounds"),
          Api::DocumentationParameter.new(
          :name => 'maps_per_page',
          :type => Integer,
          :values => (0..75),
          :test_value => 1,
          :notes => "number of maps per page"  ),
          Api::DocumentationParameter.new(
          :name => 'maps_page',
          :type => Integer,
          :default => 1,
          :test_value => 1,
          :notes =>"select specified page for maps" ),
          Api::DocumentationParameter.new(
          :name => 'texts_per_page',
          :type => Integer,
          :values => (0..75),
          :test_value => 2,
          :notes => "number of texts per page"  ),
          Api::DocumentationParameter.new(
          :name => 'texts_page',
          :type => Integer,
          :default => 1,
          :test_value => 1,
          :notes => "select specified page for texts" ),
          Api::DocumentationParameter.new(
          :name => 'subjects',
          :type => String,
          :values => "see notes",
          :default => 'overview',
          :notes => "notes on subject" ),
          Api::DocumentationParameter.new(
          :name => 'licenses',
          :type => String,
          :values => 'cc-by, cc-by-nc, cc-by-sa, cc-by-nc-sa, pd [public domain], na [not applicable], all',
          :default => 'all',
          :notes => "notes on licenses" ),
          Api::DocumentationParameter.new(
          :name => 'details',
          :type => 'Boolean',
          :test_value => true,
          :notes => "include all meta data" ),
          Api::DocumentationParameter.new(
          :name => 'common_names',
          :type => 'Boolean',
          :test_value => true,
          :notes => "return common names"),
          Api::DocumentationParameter.new(
          :name => 'synonyms',
          :type => 'Boolean',
          :test_value => true,
          :notes => "return synonyms" ),
          Api::DocumentationParameter.new(
          :name => 'references',
          :type => 'Boolean',
          :test_value => true,
          :notes => "return references"),
          Api::DocumentationParameter.new(
          :name => 'taxonomy',
          :type => 'Boolean',
          :default => true,
          :test_value => true,
          :default => true,
          :notes => "return clasifications"),
          Api::DocumentationParameter.new(
          :name => 'vetted',
          :type => Integer,
          :values =>  [ 0, 1, 2, 3, 4 ],
          :default => 0,
          :notes => "return content by vettedness" ),
          Api::DocumentationParameter.new(
          :name => 'cache_ttl',
          :type => Integer,
          :notes => "api cache time to live"),
          Api::DocumentationParameter.new(
          :name => "language",
          :type => String,
          :values => ["en", "fr"] ,
          :default => "en",
          :notes => "choose language")
        ] }

      def self.call(params)
        validate_and_normalize_input_parameters(params)
        adjust_sounds_images_videos_texts(params)
        page_requests = params[:id].split(",").map do |page_id|
          #get from database need to be changed with elasticsearch 
          page_request=Page.search(page_id, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0]  
          # page_request=request.response 
          # page_request=Page.find_by_id(id)
          {id: page_id, page: page_request}
        end.compact

        if (params[:batch] )
          batch_pages = {}
          page_requests.each do |page_request|
            pr = page_request[:page]
            raise ActiveRecord::RecordNotFound.new("Unknown page id \"#{params[:id]}\"") unless pr
            batch_pages[page_request[:id]] = prepare_hash(page_request, params.merge(batch: true))
          end
        batch_pages
        else
          page_request = page_requests.first[:page]
          raise ActiveRecord::RecordNotFound.new("Unknown page id \"#{params[:id]}\"") unless page_request
          prepare_hash(page_request, params)
        end
      end

      def self.adjust_sounds_images_videos_texts (params)
        params[:images_per_page] = adjust_param(params[:images_per_page], params[:images])
        params[:sounds_per_page] = adjust_param(params[:sounds_per_page], params[:sounds])
        params[:videos_per_page] = adjust_param(params[:videos_per_page], params[:videos])
        params[:maps_per_page] = adjust_param(params[:maps_per_page], params[:maps])
        #as text is supported with 3 synonyms
        params[:texts_per_page] = adjust_param(params[:texts_per_page], (params[:texts].blank? ? params[:text] : params[:texts]))
        params
      end

      def self.adjust_param(param_per_page, param)
        val = param_per_page.blank? ? param : param_per_page
        val.blank? ? DEFAULT_OBJECTS_NUMBER : val.to_i
      end

      def self.prepare_hash (page_hash, params={})
        return_hash = {}
        page = params[:batch] ? page_hash[:page] : page_hash
        unless page.nil?
          return_hash['identifier'] = page["_id"]
          # return_hash['scientificName'] = page.preferred_scientific_names.first.italicized
          return_hash['scientificName'] = page["_source"]["scientific_name"]
          return_hash['richness_score'] = page["_source"]["page_richness"]

          if params[:synonyms]
            return_hash["synonyms"] =
            page["_source"]["synonyms"].map do |syn|
              relation = syn.taxonomic_status.try(:name) || ""
              resource_title = syn.node.try(:resource).try(:name) || ""
              { "synonym" => syn.italicized, "relationship" => relation, "resource" => resource_title}
            end.sort {|a,b| a["synonym"] <=> b["synonym"] }.uniq
          end
# 
          if params[:common_names]
            return_hash['vernacularNames'] = []
            Vernacular.where("page_id = ? ", page["_id"]).each do |ver|
              lang = ver.language.group
              common_name_hash = {
                'vernacularName' => ver.string,
                'language'       => lang
              }
              preferred = (ver.is_preferred?) ? true : nil
              common_name_hash['eol_preferred'] = preferred unless preferred.blank?
              return_hash['vernacularNames'] << common_name_hash
            end
          end

          if params[:references]
            return_hash['references'] = []
            references = Referent.includes(:pages).where('pages.id'=> page["_id"])
            references.each do |r|
              return_hash['references'] << r.body
            end
            return_hash['references'].uniq!
          end

          if params[:taxonomy]
            return_hash['taxonConcepts'] = []
            Node.where("page_id = ?", page["_id"]).each do |node|
              node_hash = {
                'identifier'      => node.id,
                'scientificName'  => node.scientific_name ,
                'nameAccordingTo' => node.resource.name,
                'canonicalForm'   => (node.canonical_form)
              }
              node_hash['sourceIdentifier'] = node.resource_pk unless node.resource_pk.blank?
              node_hash['taxonRank'] = node.rank.name unless node.rank.nil?
              node_hash['hierarchyEntry'] = node unless params[:format] == 'json'
              return_hash['taxonConcepts'] << node_hash
            end
          end

          unless no_objects_required?(params)
            params[:licenses] = nil if params[:licenses].include?('all')
            process_license_options!(params)
            process_subject_options!(params)
            adjust_vetted_options!(params)
            
            
            return_hash['dataObjects'] = []
            
            media = Medium.search(page["_id"], fields:[{ancestry_ids: :exact}],execute: false)
            articles = Article.search(page["_id"], fields:[{ancestry_ids: :exact}], execute: false)
            Searchkick.multi_search([media,articles])
            
            load_media(media, params, page, return_hash['dataObjects'])
            load_articles(articles, params, page, return_hash['dataObjects'])
            
          end

        end

        return return_hash

      end

      def self.no_objects_required?(params)
        return (
        params[:texts_per_page] == 0 &&
        params[:images_per_page] == 0 &&
        params[:videos_per_page] == 0 &&
        params[:maps_per_page] == 0 &&
        params[:sounds_per_page] == 0
        )
      end
      
      
      def self.load_media(media, params, page, return_media)
        media_ids=media.records.map(&:id)
        license_ids=params[:licenses].map(&:id) if params[:licenses]
        
        load_images(media_ids, license_ids, params, page, return_media)   
        load_videos(media_ids, license_ids, params, page, return_media)
        load_sounds(media_ids, license_ids, params, page, return_media)  
        load_maps(media_ids, license_ids, params, page, return_media)  

      end
      
      
      def self.load_images(media_ids, license_ids, params, page, return_image)
        if params_found_and_greater_than_zero(params[:images_page], params[:images_per_page])
          
          offset = (params[:images_page]-1)*params[:images_per_page]
        
          image_objects= PageContent.images.where("id in (?)", media_ids)
          exemplar_image= Page.find_by_id(page["_id"]).medium
          promote_exemplar!(exemplar_image, image_objects, params, license_ids, page, "Medium")
          
          image_objects[offset..offset+params[:images_per_page]-1].each do |image_object|
            content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], image_object.id, "Medium").first
            
            if (params[:licenses].nil? || license_ids.include?(image_object.license_id)) && params[:vetted_types].include?(content_object.trust)
              image_hash={
                  'identifier' => image_object.guid,
                  'dataObjectVersionID' => image_object.id,
                  # 'dataType' = data_object.data_type.schema_value
                  # 'dataSubtype' = data_object.data_subtype.label rescue ''
                  'vettedStatus' => content_object.trust
                  # 'dataRatings' = data_object.rating_summary
                  # 'dataRating' = data_object.data_rating
                                 }
              if params[:details]
                # image_info= image_object.image_info                   
                # return_image['height']               = image_info.height unless image_info.height.blank?
                # return_image['width']                = image_info.width unless image_info.width.blank?
                # return_image['crop_x']               = image_info.crop_x_pct * return_image['width'] / 100.0  unless image_info.crop_x_pct.blank? || return_image['width'].blank?
                # return_image['crop_y']               = image_info.crop_y_pct * return_image['height'] / 100.0  unless image_info.crop_y_pct.blank? || return_image['height'].blank?
                # return_image['crop_height']          = image_info.crop_height_pct * return_image['height'] / 100.0  unless image_info.crop_height_pct.blank? || return_image['height'].blank?
                # return_image['crop_width'] = image_info.crop_width_pct * return_image['width'] / 100.0 unless image_info.crop_width_pct.blank? || return_image['width'].blank?  
  #               
                # return_image['mimeType'] = image_object.mime_type.label unless image_object.mime_type.blank?                
                
                image_hash['created']                = image_object.created_at unless image_object.created_at.blank?
                image_hash['modified']               = image_object.updated_at unless image_object.updated_at.blank?
                image_hash['title']                  = image_object.name unless image_object.name.blank?
                image_hash['language']               = image_object.language.group unless image_object.language.blank?
                image_hash['license']                = image_object.license.source_url unless image_object.license.blank?
                image_hash['rights']                 = image_object.rights_statement unless image_object.rights_statement.blank?
                image_hash['rightsHolder']           = image_object.owner unless image_object.owner.blank? 
                image_hash['bibliographicCitation'] = image_object.bibliographic_citation_id.body unless image_object.bibliographic_citation_id.blank?
                # image_hash['audience'] = image_object.audiences.collect{ |a| a.label }   
                
                image_hash['source']                 = image_object.source_url unless image_object.source_url.blank?
                image_hash['description']            = image_object.description unless image_object.description.blank?
                image_hash['mediaURL']               = image_object.source_page_url unless image_object.source_page_url.blank?
                # image_hash['eolMediaURL']          = DataObject.image_cache_path(image_object.object_cache_url, :orig, :specified_content_host => Rails.configuration.asset_host) unless image_object.object_cache_url.blank?
                # image_hash['eolThumbnailURL'] = DataObject.image_cache_path(image_object.object_cache_url, '98_68', :specified_content_host => Rails.configuration.asset_host) unless image_object.object_cache_url.blank?               
                
                
                unless image_object.location_id.nil? 
                  image_hash['location'] = image_object.location_id.location 
                  unless image_object.location_id.latitude == 0 && image_object.location_id.longitude == 0 && image_object.location_id.altitude == 0
                    image_hash['latitude'] = image_object.location_id.latitude 
                    image_hash['longitude'] = image_object.location_id.longitude 
                    image_hash['altitude'] = image_object.location_id.altitude 
                  end
                end
                
                
              end
              return_image << image_hash
            end
          end
        end
        
      end
      
      def self.load_videos(media_ids, license_ids, params, page, return_video)
        if params_found_and_greater_than_zero(params[:videos_page], params[:videos_per_page])
          
          offset = (params[:videos_page]-1)*params[:videos_per_page]
        
          video_objects= PageContent.videos.where("id in (?)", media_ids)
          
          video_objects[offset..offset+params[:videos_per_page]-1].each do |video_object|
            content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], video_object.id, "Medium").first
            
            if (params[:licenses].nil? || license_ids.include?(video_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                video_hash={
                  'identifier' => video_object.guid,
                  'dataObjectVersionID' => video_object.id,
                  # 'dataType' = data_object.data_type.schema_value
                  # 'dataSubtype' = data_object.data_subtype.label rescue ''
                  'vettedStatus' => content_object.trust
                  # 'dataRatings' = data_object.rating_summary
                  # 'dataRating' = data_object.data_rating
                }
                return_video << video_hash
            end
          end
        end
        
      end
      
      def self.load_sounds(media_ids, license_ids, params, page, return_sound)
        if params_found_and_greater_than_zero(params[:sounds_page], params[:sounds_per_page])
          
          offset = (params[:sounds_page]-1)*params[:sounds_per_page]
        
          sound_objects= PageContent.sounds.where("id in (?)", media_ids)
          
          sound_objects[offset..offset+params[:sounds_per_page]-1].each do |sound_object|
            content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], sound_object.id, "Medium").first
            
            if (params[:licenses].nil? || license_ids.include?(sound_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                sound_hash={
                  'identifier' => sound_object.guid,
                  'dataObjectVersionID' => sound_object.id,
                 # 'dataType' = data_object.data_type.schema_value
                  # 'dataSubtype' = data_object.data_subtype.label rescue ''
                  'vettedStatus' => content_object.trust
                  # 'dataRatings' = data_object.rating_summary
                  # 'dataRating' = data_object.data_rating
                }
                return_sound << sound_hash
            end
          end
        end
        
      end
      
      def self.load_maps(media_ids, license_ids, params, page, return_map)
         if params_found_and_greater_than_zero(params[:maps_page], params[:maps_per_page])
          
          offset = (params[:sounds_page]-1)*params[:sounds_per_page]
          
          page_object= Page.find_by_id(page["_id"])
        
          map_objects= page_object.maps
          
          map_objects[offset..offset+params[:maps_per_page]-1].each do |map_object|
            content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], map_object.id, "Medium").first
            
            if (params[:licenses].nil? || license_ids.include?(map_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                map_hash={
                  'identifier' => map_object.guid,
                  'dataObjectVersionID' => map_object.id,
                 # 'dataType' = data_object.data_type.schema_value
                  'dataSubtype' => "maps",
                  'vettedStatus' => content_object.trust
                  # 'dataRatings' = data_object.rating_summary
                  # 'dataRating' = data_object.data_rating
                }
                map_sound << map_hash
            end
          end
        end
        
      end
      
      def self.load_articles(articles, params, page, return_article)
        if params_found_and_greater_than_zero(params[:texts_page], params[:texts_per_page])
          
          articles_ids=articles.records.map(&:id)
          offset = (params[:texts_page]-1)*params[:texts_per_page]
          
          if params[:toc_items].nil? 
            article_objects= Article.where("id in (?)", articles_ids) 
          else
            content_sections= ContentSection.where("section_id in (?) and content_id in (?) and content_type = ?", params[:toc_items], articles_ids, "Article").map(&:content_id)
            article_objects= Article.where("id in (?)", content_sections)  
          end  
            article_objects[offset..offset+params[:texts_per_page]-1].each do |article_object|
              content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], article_object.id, "Article").first
              
              if (params[:licenses].nil? || license_ids.include?(article_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                  article_hash={
                    'identifier' => article_object.guid,
                    'dataObjectVersionID' => article_object.id,
                   # 'dataType' = data_object.data_type.schema_value
                    # 'dataSubtype' = data_object.data_subtype.label rescue ''
                    'vettedStatus' => content_object.trust
                    # 'dataRatings' = data_object.rating_summary
                    # 'dataRating' = data_object.data_rating
                  }
                  return_article << article_hash
              end
            end        
        end
        
      end
      
      

      def self.process_license_options!(options)
          if options[:licenses]
            options[:licenses] = options[:licenses].split("|").flat_map do |l|
              l = 'public domain' if l == 'pd'
              License.where("name REGEXP '^#{l}([^-]|$)'")
            end.compact
          end
      end
      
       def self.process_subject_options!(options)
          options[:subjects] ||= ""
          options[:text_subjects] = options[:subjects].split("|").compact
          options[:text_subjects] << 'Uses' if options[:text_subjects].include?('Use')
          if options[:subjects].blank? || options[:text_subjects].include?('overview') || options[:text_subjects].include?('all')
            options[:text_subjects] = nil
          else
            options[:text_subjects] = options[:text_subjects].flat_map do |l|
              Section.where("name = ?", l.gsub(' ','_'))
            end.compact
            options[:toc_items] = options[:text_subjects].map(&:id)
            raise Error.new("subject not found") if options[:toc_items].empty?
          end
       end
      
      def self.adjust_vetted_options!(options)
        vetted_types = {}
        if options[:vetted] == 1  # 1 = trusted
            vetted_types = ['trusted']
          elsif options[:vetted] == 2  # 2 = everything except untrusted
            vetted_types = ['trusted', 'unreviewed']
          elsif options[:vetted] == 3  # 3 = unreviewed
           vetted_types = ["unreviewed"]
          elsif options[:vetted] == 4  # 4 = untrusted
            vetted_types = ["untrusted"]
          else  # 0 = everything
            vetted_types = ['trusted', 'unreviewed', 'untrusted']
          end
        options[:vetted_types] = vetted_types
      end
      
      def self.params_found_and_greater_than_zero(page, per_page)
          page && per_page && page > 0 && per_page > 0 ? true : false
      end
      
      def self.promote_exemplar!(exemplar_object, existing_objects_of_same_type, options={}, license_ids, page, type)
        
          return unless exemplar_object
          
          # confirm license
          return if license_ids && license_ids.include?(exemplar_object.license_id)
          # user array intersection (&) to confirm the subject of the examplar is within range
          # return if options[:text_subjects] && (options[:text_subjects] & exemplar_object.toc_items).blank?

          # confirm vetted state
          content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], exemplar_object.id, type).first
          best_vetted_label = content_object.trust
          return if options[:vetted_types] && ! options[:vetted_types].include?(best_vetted_label)

          # now add in the exemplar, and remove one if the array is now too large
          original_length = existing_objects_of_same_type.length
          # remove the exemplar if it is already in the list
          existing_objects_of_same_type.delete_if { |d| d.guid == exemplar_object.guid }
          # prepend the exemplar
          existing_objects_of_same_type.unshift(exemplar_object)
          # if the exemplar increased the size of our image array, remove the last one
          existing_objects_of_same_type.pop if existing_objects_of_same_type.length > original_length && original_length != 0
      end

    end
  end
end
