require 'rails_helper'

RSpec.describe Api::Pages::V0_0 do
  context 'test prepare_hash method' do
    it "it shouldn't return details if there isn't details in params" do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      page_content = FactoryGirl.create(:page_content, page: page, content: medium)
      
      Page.reindex
      Medium.reindex
      
      page_hash = Page.search(page.id, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 

      params = {}
      params[:details] = false
      hash = Api::DataObjects::V0_0.prepare_hash(medium, params, page_hash)
      expect(hash.length).to eql(3)
      expect(hash['identifier']).to eql(medium.guid)
      expect(hash['dataObjectVersionID']).to eql(medium.id)
      expect(hash['vettedStatus']).to eql(page_content.trust)
    end
    
    it "it should return details if there is details in params" do
      medium = FactoryGirl.create(:api_medium)
      page = FactoryGirl.create(:api_page, :id => 1, :medium => medium) 
      page_content = FactoryGirl.create(:page_content, page: page, content: medium)
      
      Page.reindex
      Medium.reindex
      
      page_hash = Page.search(page.id, fields:[{id: :exact}], select: [:scientific_name, :page_richness, :synonyms]).response["hits"]["hits"][0] 

      params = {}
      params[:details] = true
      hash = Api::DataObjects::V0_0.prepare_hash(medium, params, page_hash)
      expect(hash['identifier']).to eql(medium.guid)
      expect(hash['dataObjectVersionID']).to eql(medium.id)
      expect(hash['vettedStatus']).to eql(page_content.trust)
      expect(hash['created']).to eql(medium.created_at)
      expect(hash['modified']).to eql(medium.updated_at)
      expect(hash['title']).to eql(medium.name)
      expect(hash['language']).to eql(medium.language.group)
      expect(hash['license']).to eql(medium.license.source_url)
      expect(hash['rights']).to eql(medium.rights_statement)
      expect(hash['rightsHolder']).to eql(medium.owner)
      expect(hash['bibliographicCitation']).to eql(medium.bibliographic_citation.body)
      expect(hash['source']).to eql(medium.source_url)
      expect(hash['location']).to eql(medium.location.location)
      expect(hash['latitude']).to eql(medium.location.latitude)
      expect(hash['longitude']).to eql(medium.location.longitude)
      expect(hash['altitude']).to eql(medium.location.altitude)
    end
  end
end