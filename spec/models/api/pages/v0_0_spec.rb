require 'rails_helper'

RSpec.describe Api::Pages::V0_0 do
  
  context 'test adjust params method' do
    it 'should return per_page value' do
      expect(Api::Pages::V0_0.adjust_param("5","3")).to eql(5)
    end
    it 'should return page value' do
      expect(Api::Pages::V0_0.adjust_param("","3")).to eql(3)
    end
    it 'should return default value' do
      expect(Api::Pages::V0_0.adjust_param("","")).to eql(1)
    end
  end
  
  context 'test no_objects_required? method' do
    it "should return true when action is pages and all params are zeros" do
      params={}
      params[:action]= "pages"
      params[:texts_per_page] = 0
      params[:images_per_page] = 0
      params[:videos_per_page] = 0
      params[:maps_per_page] = 0
      params[:sounds_per_page] = 0

      expect(Api::Pages::V0_0.no_objects_required?(params)).to eql(true)
    end
    
    it "should return false when action isn't pages and all params are zeros" do
      params={}
      params[:action]= "data_objects"
      params[:texts_per_page] = 0
      params[:images_per_page] = 0
      params[:videos_per_page] = 0
      params[:maps_per_page] = 0
      params[:sounds_per_page] = 0

      expect(Api::Pages::V0_0.no_objects_required?(params)).to eql(false)
    end
    
    it "should return false when action is pages and one param isn't zero" do
      params={}
      params[:action]= "pages"
      params[:texts_per_page] = 1
      params[:images_per_page] = 0
      params[:videos_per_page] = 0
      params[:maps_per_page] = 0
      params[:sounds_per_page] = 0

      expect(Api::Pages::V0_0.no_objects_required?(params)).to eql(false)
    end
  end
  
  context 'test process_license_options! method' do
    it "should return all licenses ids if there isn't any licenses" do
      params = {}
      params[:licenses] = nil
      Api::Pages::V0_0.process_license_options!(params)
      expect(params[:licenses].length).to eql(License.ids.length)
    end
    
    it "should return license id if there is license" do
      params = {}
      params[:licenses] = "public domain"
      Api::Pages::V0_0.process_license_options!(params)
      expect(params[:licenses]).to include(2)
      expect(params[:licenses].length).to eql(1)
    end 
    
    it "should return license ids if there is more than one license" do
      params = {}
      params[:licenses] = "public domain|cc-by 3.0"
      Api::Pages::V0_0.process_license_options!(params)
      expect(params[:licenses]).to include(1)
      expect(params[:licenses]).to include(2)
      expect(params[:licenses].length).to eql(2)
    end 
  end
  
  context 'test process_subject_options! method' do
    it "should return nil if it contains overview" do
      params = {}
      params[:subjects] = "overview"
      Api::Pages::V0_0.process_subject_options!(params)
      expect(params[:text_subjects]).to eql(nil)
    end
    
    it "should return nil if it contains all" do
      params = {}
      params[:subjects] = "all"
      Api::Pages::V0_0.process_subject_options!(params)
      expect(params[:text_subjects]).to eql(nil)
    end
    
    it "should raise error if it contains unknown subject" do
      params = {}
      params[:subjects] = "gbydfycv"
      expect{Api::Pages::V0_0.process_subject_options!(params)}.to raise_error(ActiveRecord::RecordNotFound)
    end
    
    it "should return section id if it contains known subject" do
      params = {}
      params[:subjects] = "brief summary"
      Api::Pages::V0_0.process_subject_options!(params)
      expect(params[:toc_items]).to include(2)
      expect(params[:toc_items].length).to eql(1)
    end 
  end  
  
  context 'test prepare_hash method' do
    it 'should return only one image and one article' do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      article = FactoryGirl.create(:api_article) 
      page_content_1 = FactoryGirl.create(:page_content, page: page, content: medium)
      page_content_2 = FactoryGirl.create(:page_content, page: page, content: article)
      
      Page.reindex
      Medium.reindex
      Article.reindex
      
      page_hash = Page.search(1, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 
      params={}
      params[:synonyms] = true
      params[:common_names] = true
      params[:taxonomy] = true
      params[:images_per_page] = 1
      params[:images_page] = 1
      params[:texts_per_page] = 1 
      params[:texts_page] = 1
      
      hash = Api::Pages::V0_0.prepare_hash(page_hash, params )
      expect(hash['identifier'].to_i).to eql(page.id)
      # expect(hash['scientificName']).to eql(page.scientific_name)
      expect(hash['richness_score']).to eql(page.page_richness)
      expect(hash['synonyms'].length).to eql(1)
      expect(hash['vernacularNames'].length).to eql(1)
      expect(hash['taxonConcepts'].length).to eql(1)
      expect(hash['dataObjects'].length).to eql(2)
      
    end
    
    it 'should return only trusted dataObjects' do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      article = FactoryGirl.create(:api_article) 
      page_content_1 = FactoryGirl.create(:page_content, page: page, content: medium)
      page_content_2 = FactoryGirl.create(:page_content, page: page, content: article)
      
      Page.reindex
      Medium.reindex
      Article.reindex
      
      page_hash = Page.search(1, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 
      params={}
      params[:synonyms] = true
      params[:common_names] = true
      params[:taxonomy] = true
      params[:images_per_page] = 1
      params[:images_page] = 1
      params[:texts_per_page] = 1 
      params[:texts_page] = 1
      params[:vetted] = 1
      
      hash = Api::Pages::V0_0.prepare_hash(page_hash, params )
      expect(hash['dataObjects'].length).to eql(0)   
    end
    
    it 'should return only dataObjects which its liceses cc-by 3.0' do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      article = FactoryGirl.create(:api_article, :license_id => 1) 
      page_content_1 = FactoryGirl.create(:page_content, page: page, content: medium)
      page_content_2 = FactoryGirl.create(:page_content, page: page, content: article)
      
      Page.reindex
      Medium.reindex
      Article.reindex
      
      page_hash = Page.search(1, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 
      params={}
      params[:synonyms] = true
      params[:common_names] = true
      params[:taxonomy] = true
      params[:images_per_page] = 1
      params[:images_page] = 1
      params[:texts_per_page] = 1 
      params[:texts_page] = 1
      params[:licenses] = "cc-by 3.0"
      
      hash = Api::Pages::V0_0.prepare_hash(page_hash, params )
      expect(hash['dataObjects'].length).to eql(1)   
    end
    
    it "should return only dataObjects which isn't hidden" do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      article = FactoryGirl.create(:api_article) 
      page_content_1 = FactoryGirl.create(:page_content, page: page, content: medium)
      page_content_2 = FactoryGirl.create(:page_content, page: page, content: article, :is_hidden => true)
      
      Page.reindex
      Medium.reindex
      Article.reindex
      
      page_hash = Page.search(1, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 
      params={}
      params[:synonyms] = true
      params[:common_names] = true
      params[:taxonomy] = true
      params[:images_per_page] = 1
      params[:images_page] = 1
      params[:texts_per_page] = 1 
      params[:texts_page] = 1
       
      hash = Api::Pages::V0_0.prepare_hash(page_hash, params )
      debugger
      expect(hash['dataObjects'].length).to eql(1)   
    end
    
    it "should return only articles which have teh requested section" do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      page_content_1 = FactoryGirl.create(:page_content, page: page, content: medium)

      section = FactoryGirl.create(:section)
      article = FactoryGirl.create(:api_article) 
      page_content_2 = FactoryGirl.create(:page_content, page: page, content: article)
      content_section = FactoryGirl.create(:content_section, content: article, section: section)
      
      Page.reindex
      Medium.reindex
      Article.reindex
      
      page_hash = Page.search(1, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 
      params={}
      params[:synonyms] = true
      params[:common_names] = true
      params[:taxonomy] = true
      params[:images_per_page] = 1
      params[:images_page] = 1
      params[:texts_per_page] = 1 
      params[:texts_page] = 1
      params[:subjects] = section.name
       
      hash = Api::Pages::V0_0.prepare_hash(page_hash, params )
      debugger
      expect(hash['dataObjects'].length).to eql(2)   
    end
    
    it "shouldn't return articles which doesn't have the requested section" do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      page_content_1 = FactoryGirl.create(:page_content, page: page, content: medium)

      section = FactoryGirl.create(:section)
      section_1 = FactoryGirl.create(:section)
      article = FactoryGirl.create(:api_article) 
      page_content_2 = FactoryGirl.create(:page_content, page: page, content: article)
      content_section = FactoryGirl.create(:content_section, content: article, section: section)
      
      Page.reindex
      Medium.reindex
      Article.reindex
      
      page_hash = Page.search(1, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 
      params={}
      params[:synonyms] = true
      params[:common_names] = true
      params[:taxonomy] = true
      params[:images_per_page] = 1
      params[:images_page] = 1
      params[:texts_per_page] = 1 
      params[:texts_page] = 1
      params[:subjects] = section_1.name
       
      hash = Api::Pages::V0_0.prepare_hash(page_hash, params )
      debugger
      expect(hash['dataObjects'].length).to eql(1)   
    end
  end
  
end