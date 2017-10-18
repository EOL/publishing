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
            adjust_vetted_options!(params)
            
            return_hash['dataObjects'] = []
            
            media = Medium.search(page["_id"], fields:[{ancestry_ids: :exact}],execute: false)
            articles = Article.search(page["_id"], fields:[{ancestry_ids: :exact}], execute: false)
            links = Link.search(page["_id"], fields:[{ancestry_ids: :exact}], execute: false)
            Searchkick.multi_search([media,articles,links])
            
            load_media(media, params, page, return_hash['dataObjects'])
            
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
      end
      
      
      def self.load_images(media_ids, license_ids, params, page, return_image)
        if params_found_and_greater_than_zero(params[:images_page], params[:images_per_page])
          
          offset = (params[:images_page]-1)*params[:images_per_page]
        
          image_objects= PageContent.images.where("id in (?)", media_ids)
          
          image_objects[offset..offset+params[:images_per_page]-1].each do |image_object|
            content_objects= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], image_object.id, "Medium")
            content_object = content_objects[0]
            
            if (params[:licenses].nil? || license_ids.include?(image_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                image_hash={
                  'identifier' => image_object.guid,
                  'dataObjectVersionID' => image_object.id,
                  'vettedStatus' => content_object.trust
          #             rating
          #             schema value
                }
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
            content_objects= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], video_object.id, "Medium")
            content_object = content_objects[0]
            
            if (params[:licenses].nil? || license_ids.include?(video_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                video_hash={
                  'identifier' => video_object.guid,
                  'dataObjectVersionID' => video_object.id,
                  'vettedStatus' => content_object.trust
          #             rating
          #             schema value
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
            content_objects= PageContent.where("page_id = ? and content_id = ? and content_type = ? ", page["_id"], sound_object.id, "Medium")
            content_object = content_objects[0]
            
            if (params[:licenses].nil? || license_ids.include?(sound_object.license_id)) && params[:vetted_types].include?(content_object.trust)
                sound_hash={
                  'identifier' => sound_object.guid,
                  'dataObjectVersionID' => sound_object.id,
                  'vettedStatus' => content_object.trust
          #             rating
          #             schema value
                }
                return_sound << sound_hash
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

    end
  end
end
