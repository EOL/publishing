module Api
  module Pages
    class V0_0 < Api::Methods
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
        page_requests = params[:id].split(",").map do |id|
          #get from database need to be changed with elasticsearch 
          # page_request=Page.search(id, fields: [:id]).records.to_a   
          # page_request=request.response 
          page_request=Page.find_by_id(id)
          {id: id, page: page_request}
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
          return_hash['identifier'] = page[0].id
          # return_hash['scientificName'] = page.preferred_scientific_names.first.italicized
          return_hash['scientificName'] = page.scientific_name
          return_hash['richness_score'] = page.page_richness rescue 0

          if params[:synonyms]
            return_hash["synonyms"] =
            page.synonyms.map do |syn|
              relation = syn.taxonomic_status.try(:name) || ""
              resource_title = syn.node.try(:resource).try(:name) || ""
              { "synonym" => syn.italicized, "relationship" => relation, "resource" => resource_title}
            end.sort {|a,b| a["synonym"] <=> b["synonym"] }.uniq
          end

          if params[:common_names]
            return_hash['vernacularNames'] = []
            page.vernaculars.each do |ver|
              lang = ver.language.group
              common_name_hash = {
                'vernacularName' => ver.string,
                'language'       => lang
              }
              preferred = (ver.is_preferred == 1) ? true : nil
              common_name_hash['eol_preferred'] = preferred unless preferred.blank?
              return_hash['vernacularNames'] << common_name_hash
            end
          end

          # if params[:references]
          # return_hash['references'] = []
          # references = Ref.find_refs_for(taxon_concept.id)
          # references = Ref.sort_by_full_reference(references)
          # references.each do |r|
          # return_hash['references'] << r.full_reference
          # end
          # return_hash['references'].uniq!
          # end

          if params[:taxonomy]
            return_hash['taxonConcepts'] = []
            page.nodes.each do |node|
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

          # unless no_objects_required?(params)
            # return_hash['dataObjects'] = []
            # data_objects = params[:data_object] ? [ params[:data_object] ] : get_data_objects(page, params)
            # data_objects.each do |data_object|
              # return_hash['dataObjects'] << EOL::Api::DataObjects::V1_0.prepare_hash(data_object, params)
            # end
          # end

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
      
      def self.get_data_objects(page, params)
        # setting some default search options which will get sent to the Solr methods
          solr_search_params = {}
          solr_search_params[:sort_by] = ['status']
          solr_search_params[:visibility_types] = ['visible']
          if params[:vetted] == 1  # 1 = trusted
            solr_search_params[:vetted_types] = ['trusted']
          elsif params[:vetted] == 2  # 2 = everything except untrusted
            solr_search_params[:vetted_types] = ['trusted', 'unreviewed']
          elsif params[:vetted] == 3  # 3 = unreviewed
            solr_search_params[:vetted_types] = ["unreviewed"]
          elsif params[:vetted] == 4  # 4 = untrusted
            solr_search_params[:vetted_types] = ["untrusted"]
          else  # 0 = everything
            solr_search_params[:vetted_types] = ['trusted', 'unreviewed', 'untrusted']
          end
          params[:vetted_types] = solr_search_params[:vetted_types]
          
          
          license = params[:licenses]
          process_license_params(params)
          solr_search_params[:license_ids] = params[:licenses].blank? ? nil : params[:licenses].collect(&:id)
          params[:license_ids] = solr_search_params[:license_ids]
          # process_subject_params!(params)
          video_objects = load_videos(page, params, solr_search_params)          
          
        
      end
      
      def self.process_license_params(params)
        params[:licenses] = nil if params[:licenses].include?('all')  
        if params[:licenses]
          params[:licenses] = params[:licenses].split("|").flat_map do |l|
            l = 'public domain' if l == 'pd'
            l = 'not applicable' if l == 'na'
            License.find(:all, :conditions => "name REGEXP '^#{l}([^-]|$)'")
          end.compact
        end
      end
      
      def self.params_found_and_greater_than_zero(page, per_page)
          page && per_page ? true : false
      end
      
      
      def self.load_videos(page, params, solr_search_params)
          video_objects = []
          if params_found_and_greater_than_zero(options[:videos_page], options[:videos_per_page])
            video_objects = page.data_objects_from_solr(solr_search_params.merge({
              page: params[:videos_page],
              per_page: params[:videos_per_page],
              data_type_ids: DataType.video_type_ids,
              return_hierarchically_aggregated_objects: true,
              filter_by_subtype: false
            }))
            video_objects.each{ |d| d.data_type = DataType.video }
          end
          return video_objects
        end

      
      # def self.process_subject_options!(options)
          # options[:subjects] ||= ""
          # options[:text_subjects] = options[:subjects].split("|")
          # options[:text_subjects] << 'Uses' if options[:text_subjects].include?('Use')
          # if options[:subjects].blank? || options[:text_subjects].include?('overview') || options[:text_subjects].include?('all')
            # options[:text_subjects] = nil
          # else
            # options[:text_subjects] = options[:text_subjects].flat_map { |l| InfoItem.cached_find_translated(:label, l, 'en', :find_all => true) }.compact
            # options[:toc_items] = options[:text_subjects].flat_map { |ii| ii.toc_item }.compact
          # end
      # end

    end
  end
end
