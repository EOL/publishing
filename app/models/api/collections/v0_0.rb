module Api
  module Collections
    class V0_0 < Api::Methods
      VERSION = '0.0'
      BRIEF_DESCRIPTION= Proc.new {"brife description" }
      DESCRIPTION= Proc.new {"API Collections" }
      PARAMETERS = Proc.new {
        [
          Api::DocumentationParameter.new(
            :name => 'id',
            :type => Integer,
            :required => true,
            :test_value => (Collection.where(:name => 'EOL Group on Flickr').first || Collection.last).id ),
          Api::DocumentationParameter.new(
            :name => 'page',
            :type => Integer,
            :default => 1 ),
          Api::DocumentationParameter.new(
            :name => 'per_page',
            :type => Integer,
            :values => (0..500),
            :default => 50 ),
          Api::DocumentationParameter.new(
            :name => 'filter',
            :type => String,
            :values => [ 'articles', 'collections', 'communities', 'images', 'sounds', 'taxa', 'users', 'video' ] ),
          Api::DocumentationParameter.new(
            :name => 'sort_by',
            :type => String,
            :values => ['recently_added', 'oldest', 'alphabetical', 'reverse_alphabetical', 'richness', 'rating', 'sort_field', 'reverse_sort_field'],
            :default => "sort_field"),
          Api::DocumentationParameter.new(
            :name => 'sort_field',
            :type => String,
            :notes => "sort field"),
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
        
        
      def self.call(params={})
        validate_and_normalize_input_parameters(params)
          # I18n.locale = params[:language] unless params[:language].blank?
        if params[:sort_by].class != String
          params[:sort_by] = nil
        end
          begin
            # collection = Collection.find(params[:id], include: [ :sort_style ])
            collection= Collection.search(params[:id], fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]  
            params[:sort_by] ||= collection["_source"]["default_sort"]
          rescue
            raise ActiveRecord::RecordNotFound.new("Unknown collection id \"#{params[:id]}\"")
          end
          prepare_hash(collection, params)
      end
      
      
      def self.prepare_hash(collection, params)
        # facet_counts = EOL::Solr::CollectionItems.get_facet_counts(collection.id)
          # collection_results = collection.items_from_solr(:facet_type => params[:filter], :page => params[:page], :per_page => params[:per_page],
            # :sort_by => params[:sort_by], :view_style => ViewStyle.list, :sort_field => params[:sort_field])
          # collection_items = collection_results.map { |i| i['instance'] }
          # CollectionItem.preload_associations(collection_items, :refs)
          return_hash = {}
          return_hash['name'] = collection["_source"]["name"]
          return_hash['description'] = collection["_source"]["description"]
          # return_hash['logo_url'] = collection.logo_cache_url.blank? ? nil : collection.logo_url
          return_hash['created'] = collection["_source"]["created_at"]
          return_hash['modified'] = collection["_source"]["updated_at"]
          
          collection_object=Collection.find_by_id(collection["_id"])
          
          counts ={}
          collection_object.collected_pages.each do |collected_page|
            counts['articles'].nil? ? counts['articles'] = collected_page.articles.count : counts['articles'] +=collected_page.articles.count
            counts['video'].nil? ? counts['video'] = collected_page.media.where(subclass: 1).count : counts['video'] +=collected_page.media.where(subclass: 1).count
            counts['images'].nil? ? counts['images'] = collected_page.media.where(subclass: 0).count : counts['images'] +=collected_page.media.where(subclass: 0).count
            counts['sounds'].nil? ? counts['sounds'] = collected_page.media.where(subclass: 2).count : counts['sounds'] +=collected_page.media.where(subclass: 2).count
          end
          counts['taxa'] =  collection_object.collected_pages.count
          counts['users'] =  collection_object.users.count
          counts['collections'] =  collection_object.collections.count
          
          
          
          return_hash['total_items'] =  adjust_total_items_count(params, counts)

          
          return_hash['item_types'] = []
          return_hash['item_types'] << { 'item_type' => "TaxonConcept", 'item_count' => counts['taxa']}
          
          return_hash['item_types'] << { 'item_type' => "Text", 'item_count' => counts['articles'] }
          
          
          return_hash['item_types'] << { 'item_type' => "Video", 'item_count' => counts['video'] }
          return_hash['item_types'] << { 'item_type' => "Image", 'item_count' => counts['images'] }
          return_hash['item_types'] << { 'item_type' => "Sound", 'item_count' => counts['sounds'] }
          return_hash['item_types'] << { 'item_type' => "User", 'item_count' => counts['users'] }
          return_hash['item_types'] << { 'item_type' => "Collection", 'item_count' => counts['collections'] }
          
          # this is dummy data without sorting
          count = params[:per_page]
          return_hash['collection_items'] = []
          collection_object.collected_pages.each do |collected_page|
          
            item_hash = {
                'name' => collected_page.page.scientific_name,
                'object_type' => "TaxonConcept",
                'object_id' => collected_page.page_id,
                'title' => collected_page.page.scientific_name,
                'created' => collected_page.created_at,
                'updated' => collected_page.updated_at,
                'annotation' => collected_page.annotation,
                'richness_score' => sprintf("%.5f", collected_page.page.page_richness || 0 * 100.00).to_f
                # 'sort_field' => ci.sort_field
            }
            
            return_hash['collection_items'] << item_hash
          end
          count -= counts['taxa']
          if count > 0 
            #show articles 
          end
          count -= counts['articles']
          if count > 0 
            #show images
            collection_object.collected_pages.each do |collected_page|
              collected_page.media.images.each do |image|
                item_hash = {
                  'name' => image.name,
                  'object_type' => "Image",
                  'object_id' => image.id,
                  'title' => image.name,
                  'created' => image.created_at,
                  'updated' => image.updated_at,
                  # 'annotation' => collected_page.annotation,
                  # 'sort_field' => ci.sort_field
                  'object_guid' => image.guid,
                  'source' =>  image.source_url
              }
              end
            end
          end
          

          return return_hash
      end
      
      def self.adjust_total_items_count(params, counts)
        if params[:filter].nil?
          return counts.values.reduce(:+)
        else
          return counts[params[:filter]]
        end
      end
    end
  end
end