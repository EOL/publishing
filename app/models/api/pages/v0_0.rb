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
          return_hash['scientificName'] = page["_source"]["scientific_name"]
          return_hash['richness_score'] = page["_source"]["page_richness"]

          if params[:synonyms]
            return_hash["synonyms"] =
            page["_source"]["synonyms"].map do |syn|
              syn_object= ScientificName.where("page_id = ? and canonical_form = ?", page["_id"], syn).first
              relation = syn_object.taxonomic_status.try(:name) || ""
              resource_title = syn_object.node.try(:resource).try(:name) || ""
              { "synonym" => syn_object.italicized, "relationship" => relation, "resource" => resource_title}
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
                'canonicalForm'   => node.canonical_form
              }
              node_hash['sourceIdentifier'] = node.resource_pk unless node.resource_pk.blank?
              node_hash['taxonRank'] = node.rank.name unless node.rank.nil?
              node_hash['hierarchyEntry'] = node unless params[:format] == 'json'
              return_hash['taxonConcepts'] << node_hash
            end
          end

          unless no_objects_required?(params)
            return_hash['dataObjects'] = []
            data_objects = params[:data_object] ? [ params[:data_object] ] : get_data_objects(page, params)
            data_objects.each do |data_object|
              return_hash['dataObjects'] << Api::DataObjects::V0_0.prepare_hash(data_object, params, page)
              end
          end

        end

        return return_hash

      end

      def self.no_objects_required?(params)
        return (
        params[:action] == "pages" &&
        params[:texts_per_page] == 0 &&
        params[:images_per_page] == 0 &&
        params[:videos_per_page] == 0 &&
        params[:maps_per_page] == 0 &&
        params[:sounds_per_page] == 0
        )
      end
      
      def self.get_data_objects(page, params)
        params[:licenses] = nil if params[:licenses] && params[:licenses].include?('all')
        process_license_options!(params)
        process_subject_options!(params)
        adjust_vetted_options!(params)
                        
        media = Medium.search(page["_id"], fields:[{ancestry_ids: :exact}],execute: false)
        articles = Article.search(page["_id"], fields:[{ancestry_ids: :exact}], execute: false)
        links = Link.search(page["_id"], fields:[{ancestry_ids: :exact}], execute: false)
        Searchkick.multi_search([media, articles, links])
            
        media_objects = load_media(media, params, page)
        articles_objects = load_articles(articles, params, page)
        links_objects = load_links(links, params, page)
        all_data_objects = [ media_objects, articles_objects, links_objects ].flatten.compact
        
        return all_data_objects
      end
      
      
      def self.load_media(media, params, page)
        media_ids=media.records.map(&:id)
        content_ids = PageContent.where("page_id = ? and content_id in (?) and content_type = ? and trust in (?) and is_incorrect = ? and is_misidentified = ? and is_hidden = ? and is_duplicate = ?", page["_id"], media_ids, "Medium", params[:vetted_types], false, false, false, false).map(&:content_id)
        media_ids = media_ids & content_ids
        
        image_objects = load_images(media_ids, params[:licenses], params, page)   
        video_objects = load_videos(media_ids, params[:licenses], params, page)
        sound_objects = load_sounds(media_ids, params[:licenses], params, page)  
        map_objects = load_maps(media_ids, params[:licenses], params, page) 
        
        all_media_objects = [ image_objects, video_objects, sound_objects, map_objects ].flatten.compact
        return all_media_objects

      end
      
      
      def self.load_images(media_ids, license_ids, params, page)
        if params_found_and_greater_than_zero(params[:images_page], params[:images_per_page])  
          offset = (params[:images_page]-1)*params[:images_per_page]
          image_objects= PageContent.images.where("id in (?) and license_id in (?)", media_ids, license_ids) 
          exemplar_image= Page.find_by_id(page["_id"]).medium
          promote_exemplar!(exemplar_image, image_objects, params, license_ids, page, "Medium")
          return image_objects[offset..offset+params[:images_per_page]-1]
          
        end
        
      end
      
      def self.load_videos(media_ids, license_ids, params, page)
        if params_found_and_greater_than_zero(params[:videos_page], params[:videos_per_page])
          
          offset = (params[:videos_page]-1)*params[:videos_per_page]
        
          video_objects= PageContent.videos.where("id in (?) and license_id in (?)", media_ids, license_ids)
          
          return video_objects[offset..offset+params[:videos_per_page]-1]
          
        end
        
      end
      
      def self.load_sounds(media_ids, license_ids, params, page)
        if params_found_and_greater_than_zero(params[:sounds_page], params[:sounds_per_page])
          
          offset = (params[:sounds_page]-1)*params[:sounds_per_page]
        
          sound_objects= PageContent.sounds.where("id in (?) and license_id in (?)", media_ids, license_ids)
          
          return sound_objects[offset..offset+params[:sounds_per_page]-1]
          
        end
        
      end
      
      def self.load_maps(media_ids, license_ids, params, page)
         if params_found_and_greater_than_zero(params[:maps_page], params[:maps_per_page])
          
          offset = (params[:sounds_page]-1)*params[:sounds_per_page]
          
          page_object= Page.find_by_id(page["_id"])
        
          map_objects= page_object.maps.where("license_id in (?)", license_ids)
          
          return map_objects[offset..offset+params[:maps_per_page]-1]
          
        end
        
      end
      
      def self.load_articles(articles, params, page)
        if params_found_and_greater_than_zero(params[:texts_page], params[:texts_per_page])
          articles_ids=articles.records.map(&:id)
          content_ids = PageContent.where("page_id = ? and content_id in (?) and content_type = ? and trust in (?) and is_incorrect = ? and is_misidentified = ? and is_hidden = ? and is_duplicate = ?", page["_id"], articles_ids, "Article", params[:vetted_types], false, false, false, false).map(&:content_id)
          articles_ids = articles_ids & content_ids
          
          offset = (params[:texts_page]-1)*params[:texts_per_page]
          
          if params[:toc_items].nil? 
            article_objects= Article.where("id in (?) and license_id in (?)", articles_ids, params[:licenses]) 
          else
            content_sections= ContentSection.where("section_id in (?) and content_id in (?) and content_type = ?", params[:toc_items], articles_ids, "Article").map(&:content_id)
            article_objects= Article.where("id in (?) and license_id in (?)", content_sections, params[:licenses])  
          end 
          
          return article_objects[offset..offset+params[:texts_per_page]-1]   
        end
      end
      
      #assume links are a type of dataoject and subtype from articles
      def self.load_links(links, params, page)
        if params_found_and_greater_than_zero(params[:texts_page], params[:texts_per_page])
          links_ids=links.records.map(&:id)
          content_ids = PageContent.where("page_id = ? and content_id in (?) and content_type = ? and trust in (?) and is_incorrect = ? and is_misidentified = ? and is_hidden = ? and is_duplicate = ?", page["_id"], links_ids, "Link", params[:vetted_types], false, false, false, false).map(&:content_id)
          links_ids = links_ids & content_ids
          
          offset = (params[:texts_page]-1)*params[:texts_per_page]
          
          link_objects= Link.where("id in (?)", params[:licenses])
          return link_objects[offset..offset+params[:texts_per_page]-1]
        end
      end
      
      def self.process_license_options!(options)
        if options[:licenses]
          options[:licenses] = options[:licenses].split("|").flat_map do |l|
            l = 'public domain' if l == 'pd'
            License.where("name REGEXP '^#{l}([^-]|$)'")
          end.compact.map(&:id)
        else
          options[:licenses]=License.ids
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
          raise ActiveRecord::RecordNotFound.new("subject not found") if options[:toc_items].empty?
        end
      end
      
      def self.adjust_vetted_options!(options)
        vetted_types = {}
        if options[:vetted] == 1  # 1 = trusted
            vetted_types = [1]
          elsif options[:vetted] == 2  # 2 = everything except untrusted
            vetted_types = [1, 0]
          elsif options[:vetted] == 3  # 3 = unreviewed
           vetted_types = [0]
          elsif options[:vetted] == 4  # 4 = untrusted
            vetted_types = [2]
          else  # 0 = everything
            vetted_types = [0, 1, 2]
          end
        options[:vetted_types] = vetted_types
      end
      
      def self.params_found_and_greater_than_zero(page, per_page)
          page && per_page && page > 0 && per_page > 0 ? true : false
      end
      
      def self.promote_exemplar!(exemplar_object, existing_objects_of_same_type, options={}, license_ids, page, type)
          return unless exemplar_object
          return unless license_ids.include?(exemplar_object.license_id)
         
          content_object= PageContent.where("page_id = ? and content_id = ? and content_type = ? and is_incorrect = ? and is_misidentified = ? and is_hidden = ? and is_duplicate = ?", page["_id"], exemplar_object.id, type, false, false, false, false).first
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
