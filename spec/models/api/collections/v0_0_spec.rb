require 'rails_helper'

RSpec.describe Api::Collections::V0_0 do

  context 'test adjust_total_items_count method' do
    counts = {}
    counts['taxa'] = 1
    counts['users'] = 2
    counts['collections'] = 3
    counts['articles'] = 4
    counts['video'] = 5
    counts['images'] = 6
    counts['sounds'] = 7

    params = {}

    it 'should return sum of all counts' do
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(28)
    end

    it 'should return taxa count' do
      params[:filter] = "taxa"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(1)
    end
    
    it 'should return users count' do
      params[:filter] = "users"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(2)
    end
    
    it 'should return collections count' do
      params[:filter] = "collections"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(3)
    end
    
    it 'should return articles count' do
      params[:filter] = "articles"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(4)
    end
    
    it 'should return video count' do
      params[:filter] = "video"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(5)
    end
    
    it 'should return images count' do
      params[:filter] = "images"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(6)
    end
    
    it 'should return sounds count' do
      params[:filter] = "sounds"
      expect(Api::Collections::V0_0.adjust_total_items_count(params, counts)).to eql(7)
    end
  end
  
  context 'test prepare_hash method' do
    # collection_hash = []
    collection, medium_1, medium_2, page, page_2, collected_page_1, collected_page_2, collected_page_medium, collected_page_medium_2 =nil
    
    before(:each) do
      collection = FactoryGirl.create(:collection)
      medium_1 = FactoryGirl.create(:api_medium)
      medium_2 = FactoryGirl.create(:api_medium)
      page_1 = FactoryGirl.create(:api_page) 
      page_2 = FactoryGirl.create(:api_page, page_richness: 2)      
      collected_page_1 = FactoryGirl.create(:api_collected_page, collection: collection, page: page_1 )
      collected_page_medium_1 = FactoryGirl.create(:collected_pages_medium, collected_page: collected_page_1, medium: medium_1)
      collected_page_2 = FactoryGirl.create(:api_collected_page, collection: collection, page: page_2 )
      collected_page_medium_2 = FactoryGirl.create(:collected_pages_medium, collected_page: collected_page_2, medium: medium_2)
      Collection.reindex
      
    end
    it "should return true counts of collection's items" do
      collection_hash = Collection.search(collection.id, fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]

      params = {}
      params[:per_page] = 1
      params[:sort_by] = "recently_added"
      hash = Api::Collections::V0_0.prepare_hash(collection_hash, params)
      
      expect(hash['name']).to eql(collection.name)
      expect(hash['description']).to eql(collection.description)
      expect(hash['created']).to eql(collection_hash["_source"]["created_at"])
      expect(hash['modified']).to eql(collection_hash["_source"]["updated_at"])
      
      expect(hash['item_types'][0]['item_count']).to eql(2) #taxa
      expect(hash['item_types'][1]['item_count']).to eql(2) #articles
      expect(hash['item_types'][2]['item_count']).to eql(0) #video
      expect(hash['item_types'][3]['item_count']).to eql(2) #images
      expect(hash['item_types'][4]['item_count']).to eql(0) #sounds
      expect(hash['item_types'][5]['item_count']).to eql(1) #users
      expect(hash['item_types'][6]['item_count']).to eql(0) #collections
    end
    
    it 'should return item sorted by page richness and id descading' do
      collection_hash = Collection.search(collection.id, fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]
      params = {}
      params[:sort_by] = "richness"
      hash = Api::Collections::V0_0.prepare_hash(collection_hash, params)
      
      expect(hash['collection_items'][0]['object_id']).to eql(collected_page_2.id*300)
      expect(hash['collection_items'][1]['object_id']).to eql(medium_2.id)
      expect(hash['collection_items'][2]['object_id']).to eql(collected_page_1.id*300)
      expect(hash['collection_items'][3]['object_id']).to eql(medium_1.id)

    end
    
    it 'should return item sorted by alphabetical and id ascading' do
      collection_hash = Collection.search(collection.id, fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]
      params = {}
      params[:sort_by] = "alphabetical"
      hash = Api::Collections::V0_0.prepare_hash(collection_hash, params)
      expect(hash['collection_items'][0]['object_id']).to eql(medium_1.id)
      expect(hash['collection_items'][1]['object_id']).to eql(collected_page_1.id*300)
      expect(hash['collection_items'][2]['object_id']).to eql(medium_2.id)
      expect(hash['collection_items'][3]['object_id']).to eql(collected_page_2.id*300)
    end
    
    it 'should return item sorted by reverse alphabetical and id descading' do
      collection_hash = Collection.search(collection.id, fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]
      params = {}
      params[:sort_by] = "reverse_alphabetical"
      hash = Api::Collections::V0_0.prepare_hash(collection_hash, params)
      expect(hash['collection_items'][0]['object_id']).to eql(collected_page_2.id*300)
      expect(hash['collection_items'][1]['object_id']).to eql(medium_2.id)
      expect(hash['collection_items'][2]['object_id']).to eql(collected_page_1.id*300)
      expect(hash['collection_items'][3]['object_id']).to eql(medium_1.id)
    end
    
  end
  
  context 'test adjust_requseted_items method' do
    params ={}
    articles, videos, images, sounds, taxas, users, collections, total_items = [], [], [], [], [], [], [], []
    let(:user) { create(:user) }
    let(:article) { create(:api_article)}
    let(:video) { create(:api_medium) }
    let(:image) { create(:api_medium) }
    let(:sound) { create(:api_medium) }
    let(:taxa) { create(:api_page) }
    let(:collection) { create(:collection_without_user) }
    
    before(:each) do
      articles.clear
      videos.clear
      images.clear
      sounds.clear
      taxas.clear
      users.clear
      collections.clear

      articles << article
      videos << video
      images << image
      sounds << sound
      taxas << taxa
      users << user
      collections << collection
      
      total_items = articles+videos+images+sounds
    end
   
    it 'should return all items' do
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(7)
    end
    
    it 'should return only articles' do
      params [:filter] = "articles"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(articles.first.id)
    end
    
    it 'should return only images' do
      params [:filter] = "images"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(images.first.id)
    end
    
    it 'should return only videos' do
      params [:filter] = "video"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(videos.first.id)
    end
    
    it 'should return only sounds' do
      params [:filter] = "sounds"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(sounds.first.id)
    end
    
    it 'should return only pages' do
      params[:filter] = "taxa"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(taxas.first.id)
    end
    
    it 'should return only users' do
      params [:filter] = "users"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(users.first.id)
    end
    
    it 'should return only collections' do
      params [:filter] = "collections"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(collections.first.id)
    end
    
    it 'should return all items as filter not found' do
      params [:filter] = "vdhgvdgdvgd"
      items = Api::Collections::V0_0.adjust_requseted_items(params, articles, videos, images, sounds, taxas, users, collections, total_items)
      expect(items.length).to eql(7)
    end

  end
  
  context 'test sort_items method' do
    it 'should adjsut page and per_page params' do
      params ={}
      items = []
      Api::Collections::V0_0.sort_items(params, items)
      expect(params[:per_page]).to eql(40)
      expect(params[:page]).to eql(1)
    end
    
    it 'should adjsut per_page params if it is zero' do
      params ={}
      params[:per_page] = 0
      items = []
      Api::Collections::V0_0.sort_items(params, items)
      expect(params[:per_page]).to eql(40)
      expect(params[:page]).to eql(1)
    end
    
    it 'should return sorted items by data ascading' do
      params ={}
      items = []
      params[:sort_by] = "oldest"
      medium_1 = FactoryGirl.create(:api_medium)
      medium_2 = FactoryGirl.create(:api_medium, created_at: Date.new(2017,3,5))
      items << medium_1
      items << medium_2
      items = Api::Collections::V0_0.sort_items(params, items)
      expect(items.first.id).to eql(medium_2.id)
      expect(items.second.id).to eql(medium_1.id)
    end
    
    it 'should return sorted items by data descading' do
      params ={}
      items = []
      params[:sort_by] = "recently_added"
      medium_1 = FactoryGirl.create(:api_medium, created_at: Date.new(2017,3,5))
      medium_2 = FactoryGirl.create(:api_medium)
      items << medium_1
      items << medium_2
      items = Api::Collections::V0_0.sort_items(params, items)
      expect(items.first.id).to eql(medium_2.id)
      expect(items.second.id).to eql(medium_1.id)
    end
    
    it 'should return items acordding to requested pages' do
      params ={}
      params[:per_page] = 1
      params[:page] = 2
      items = []
      medium_1 = FactoryGirl.create(:api_medium, created_at: Date.new(2017,3,5))
      medium_2 = FactoryGirl.create(:api_medium)
      items << medium_1
      items << medium_2
      items = Api::Collections::V0_0.sort_items(params, items)
      expect(items.length).to eql(1)
      expect(items.first.id).to eql(medium_2.id)
    end
    
    it 'should return zero items' do
      params ={}
      params[:per_page] = 1
      params[:page] = 3
      items = []
      medium_1 = FactoryGirl.create(:api_medium, created_at: Date.new(2017,3,5))
      medium_2 = FactoryGirl.create(:api_medium)
      items << medium_1
      items << medium_2
      items = Api::Collections::V0_0.sort_items(params, items)
      expect(items.length).to eql(0)
    end
  end

end