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
            :values => [ 'articles', 'collections', 'images', 'sounds', 'taxa', 'users', 'video' ] ),
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
          I18n.locale = params[:language] unless params[:language].blank?
        if params[:sort_by].class != String
          params[:sort_by] = nil
        end
          begin
            collection= Collection.search(params[:id], fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]  
            params[:sort_by] ||= collection["_source"]["default_sort"]
          rescue
            raise ActiveRecord::RecordNotFound.new("Unknown collection id \"#{params[:id]}\"")
          end
        prepare_hash(collection, params)
      end
      
      
      def self.prepare_hash(collection, params)
        return_hash = {}
        return_hash['name'] = collection["_source"]["name"]
        return_hash['description'] = collection["_source"]["description"]
        return_hash['logo_url'] = ""
        return_hash['created'] = collection["_source"]["created_at"]
        return_hash['modified'] = collection["_source"]["updated_at"]
          
        collection_object=Collection.find_by_id(collection["_id"])
          
        counts ={}
        @articles, @video, @images, @sounds, @taxa, @users, @collections, @total_items = [], [], [], [], [], [], [], [] 
        collected_pages = collection_object.collected_pages
        
        if params[:sort_by].eql? "richness"
          collected_pages = collected_pages.sort_by(&:page_richness).reverse!
        elsif params[:sort_by].eql? "alphabetical"
          collected_pages = collected_pages.sort_by(&:native_node_name)
        elsif params[:sort_by].eql? "reverse_alphabetical" 
          collected_pages = collected_pages.sort_by(&:native_node_name).reverse!
        end  
        
        collected_pages.each do |collected_page|
          counts['articles'].nil? ? counts['articles'] = collected_page.articles.count : counts['articles'] +=collected_page.articles.count
          counts['images'].nil? ? counts['images'] = collected_page.media.where(subclass: 0).count : counts['images'] +=collected_page.media.where(subclass: 0).count
          counts['video'].nil? ? counts['video'] = collected_page.media.where(subclass: 1).count : counts['video'] +=collected_page.media.where(subclass: 1).count
          counts['sounds'].nil? ? counts['sounds'] = collected_page.media.where(subclass: 2).count : counts['sounds'] +=collected_page.media.where(subclass: 2).count
          
          @collected_page_items = []
          @articles += collected_page.articles
          @collected_page_items += collected_page.articles
          @images += collected_page.media.where(subclass: 0)
          @collected_page_items += collected_page.media.where(subclass: 0)
          @video += collected_page.media.where(subclass: 1)
          @collected_page_items += collected_page.media.where(subclass: 1)
          @sounds += collected_page.media.where(subclass: 2)
          @collected_page_items += collected_page.media.where(subclass: 2)
          
          if (params[:sort_by].eql? "richness") || (params[:sort_by].eql? "reverse_alphabetical")
            @collected_page_items = @collected_page_items.sort_by(&:id).reverse!
          elsif params[:sort_by].eql? "alphabetical"
            @collected_page_items = @collected_page_items.sort_by(&:id)
          end
          @total_items += @collected_page_items
          
        end
        counts['taxa'] =  collection_object.collected_pages.count
        counts['users'] =  collection_object.users.count
        counts['collections'] =  collection_object.collections.count
        
        @taxa += collection_object.pages
        @users += collection_object.users
        @collections += collection_object.collections
        
          
        return_hash['total_items'] =  adjust_total_items_count(params, counts)

        return_hash['item_types'] = []
        return_hash['item_types'] << { 'item_type' => "TaxonConcept", 'item_count' => counts['taxa']}
        return_hash['item_types'] << { 'item_type' => "Text", 'item_count' => counts['articles'] }
        return_hash['item_types'] << { 'item_type' => "Video", 'item_count' => counts['video'] }
        return_hash['item_types'] << { 'item_type' => "Image", 'item_count' => counts['images'] }
        return_hash['item_types'] << { 'item_type' => "Sound", 'item_count' => counts['sounds'] }
        return_hash['item_types'] << { 'item_type' => "User", 'item_count' => counts['users'] }
        return_hash['item_types'] << { 'item_type' => "Collection", 'item_count' => counts['collections'] }
        
        @items = adjust_requseted_items(params, @articles, @video, @images, @sounds, @taxa, @users, @collections, @total_items)
        
        return_hash['collection_items'] = []
        @items.each do |item|
          item_hash = {
            'name' => item.name,
            'object_type' => item.class.name,
            'object_id' => item.id,
            # 'title' => collected_page.name,
            'created' => item.created_at,
            'updated' => item.updated_at,
            # 'annotation' => collected_page.annotation,
            # 'sort_field' => ci.sort_field
          }
          
          if item.kind_of? Page
            item_hash['richness_score'] = sprintf("%.5f", item.page_richness * 100.00).to_f
          elsif (item.kind_of? Article) || (item.kind_of? Medium)
            item_hash['data_rating'] = ""
            item_hash['object_guid'] = item.guid
            item_hash['object_type'] = item.subclass if item.kind_of? Medium
          end
          
          return_hash['collection_items'] << item_hash
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
      
      def self.adjust_requseted_items(params, articles, videos, images, sounds, taxa, users, collections, total_items)
        @items = []
        if params[:filter].eql? "taxa"
          @items = taxa
        elsif params[:filter].eql? "articles"
          @items = articles
        elsif params[:filter].eql? "video"
          @items = videos
        elsif params[:filter].eql? "images"
          @items = images
        elsif params[:filter].eql? "sounds"
          @items = sounds
        elsif params[:filter].eql? "users"
          @items = users
        elsif params[:filter].eql? "collections"
          @items = collections
        else
          @items = total_items+taxa+users+collections
        end
        
        return sort_items(params, @items)
        
      end
      
      def self.sort_items(params, items)
        if params[:sort_by].eql? "recently_added"
          items = items.compact.sort_by(&:created_at).reverse!
        elsif params[:sort_by].eql? "oldest"
          items = items.compact.sort_by(&:created_at)
        # elsif params[:sort_by].eql? "alphabetical"
        # elsif params[:sort_by].eql? "reverse_alphabetical"
        # elsif params[:sort_by].eql? "richness"
        # elsif params[:sort_by].eql? "rating"
        elsif params[:sort_by].eql? "sort_field"
        elsif params[:sort_by].eql? "reverse_sort_field"
        end
        
        
        params[:page] ||= 1
        params[:per_page] ||= 40
        params[:per_page] = 40 if params[:per_page] == 0

        
        offset = (params[:page]-1)*params[:per_page]
        return items[offset..offset+params[:per_page]-1]
      end
    end
  end
end