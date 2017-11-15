require 'rails_helper'

RSpec.describe Api::Pages do
  it 'data objects should be able to render a JSON response' do
    medium = FactoryGirl.create(:medium, :id => 1, :name => "test", :rights_statement => "rights", :owner => "owner", :bibliographic_citation_id => 1)
    visit "/api/data_objects/#{medium.guid}.json"
    response = JSON.parse(source)
    response.class.should = Hash
    response['dataObjects'][0]['identifier'].should = medium.guid
    # response['dataObjects'][0]['dataType'].should = medium.data_type.schema_value
    # response['dataObjects'][0]['mimeType'].should = medium.mime_type.label
    response['dataObjects'][0]['title'].should = medium.name
    response['dataObjects'][0]['language'].should = medium.language.group
    response['dataObjects'][0]['license'].should = medium.license.source_url
    response['dataObjects'][0]['rights'].should = medium.rights_statement
    response['dataObjects'][0]['rightsHolder'].should = medium.owner
    response['dataObjects'][0]['bibliographicCitation'].should = medium.bibliographic_citation_id.body
    response['dataObjects'][0]['source'].should = medium.source_url
    # /fgmpresponse['dataObjects'][0]['subject'].should = medium.info_items[0].schema_value
    response['dataObjects'][0]['description'].should = medium.description
    response['dataObjects'][0]['location'].should = medium.location
    response['dataObjects'][0]['latitude'].should = medium.latitude
    response['dataObjects'][0]['longitude'].should = medium.longitude
    response['dataObjects'][0]['altitude'].should = medium.altitude

  end
end