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
  
  
end