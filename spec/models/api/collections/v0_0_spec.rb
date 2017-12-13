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
    it "should return true counts of collection's items" do
      collection = FactoryGirl.create(:collection)
      medium_1 = FactoryGirl.create(:api_medium)
      medium_2 = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page) 
      page_2 = FactoryGirl.create(:api_page)      
      
      collected_page_1 = FactoryGirl.create(:api_collected_page, collection: collection, page: page )
      collected_page_medium = FactoryGirl.create(:collected_pages_medium, collected_page: collected_page_1, medium: medium_1)
      
      collected_page_2 = FactoryGirl.create(:api_collected_page, collection: collection, page: page_2 )
      collected_page_medium_2 = FactoryGirl.create(:collected_pages_medium, collected_page: collected_page_2, medium: medium_2)
      
      Page.reindex
      Medium.reindex
      Collection.reindex
      
      collection_hash = Collection.search(collection.id, fields:[{id: :exact}], select: [:default_sort, :name, :description, :created_at, :updated_at]).response["hits"]["hits"][0]
      params = {}
      params[:per_page] = 1
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
  end

end