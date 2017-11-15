require 'rails_helper'

RSpec.describe Api::Pages do
  # let(:page) { create(:api_page, :id => 999) }
  
  context 'JSON response format' do
    it 'should return array of length 1 for one id' do
      page = FactoryGirl.create(:api_page, :id => 1)
      visit "/api/pages/0.0.json?batch=true&id=#{page.id}&images_page=0&images_per_page=0&texts_page=0&texts_per_page=0&videos_page=0&videos_per_page=0&maps_per_page=0&sounds_per_page=0&details=0"
      response = JSON.parse(source)
      expect(response.length).to eq(1)
    end
    
    it 'should return array of length 2 for three ids' do
      page_0 = FactoryGirl.create(:api_page, :id => 1)
      page_1 = FactoryGirl.create(:api_page, :id => 2)
      visit "/api/pages/0.0.json?batch=true&id=#{page_0.id}%2C#{page_1.id}&images_page=0&images_per_page=0&texts_page=0&texts_per_page=0&videos_page=0&videos_per_page=0&maps_per_page=0&sounds_per_page=0&details=0"
      response = JSON.parse(source)
      expect(response.length).to eq(2)
    end  
  end
  
  context 'xml response format' do
    it 'should have taxonConcepts element' do
      page = FactoryGirl.create(:api_page, :id => 1)
      visit "/api/pages/0.0.xml?batch=false&id=#{page.id}&images_page=0&images_per_page=0&texts_page=0&texts_per_page=0&videos_page=0&videos_per_page=0&maps_per_page=0&sounds_per_page=0&details=0"
      response = Nokogiri::XML(source)
      response.remove_namespaces!
      expect(response.xpath('//taxonConcept').length).to eq(1)
    end
  end
end
