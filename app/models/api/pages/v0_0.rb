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
        if params[:licenses].nil?
          media.response["hits"]["hits"].each do |medium|
              medium_id= medium["_id"]
              content_objects= PageContent.where("page_id = ? and content_id = ?", page["_id"], medium_id)
              content_object=content_objects[0]
              medium_object= Medium.find_by_id(medium_id)
              
              media_hash={
                'identifier' => medium_object.guid,
                'dataObjectVersionID' => medium_object.id,
                'vettedStatus' => content_object.trust
    #             rating
    #             schema value
              }
              
              return_media << media_hash
          end
        else
          license_ids=params[:licenses].map(&:id)
          media.response["hits"]["hits"].each do |medium|
              medium_id= medium["_id"]
              medium_object= Medium.find_by_id(medium_id)
              
              if license_ids.include?(medium_object.license_id)
                content_objects= PageContent.where("page_id = ? and content_id = ?", page["_id"], medium_id)
                content_object=content_objects[0]
                
                media_hash={
                  'identifier' => medium_object.guid,
                  'dataObjectVersionID' => medium_object.id,
                  'vettedStatus' => content_object.trust
      #             rating
      #             schema value
                }
                
                return_media << media_hash
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

    end
  end
end
