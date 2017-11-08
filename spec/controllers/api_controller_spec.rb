require 'rails_helper'
RSpec.describe ApiController do

  it 'there should be 3 API methods' do
    # [ :pages ]
    Api::METHODS.length.should == 3
  end
  
  it 'should load the class corresponding to each API method' do
    Api::METHODS.each do |method_name|
      latest_version_method = Api.default_version_of(method_name)
      get method_name
      assigns[:api_method].should == latest_version_method
    end
  end
  
  it 'should set cache headers' do
    get :pages, :params => {:id => 328598, :cache_ttl => 100}
    expect(response.header['Cache-Control']).to eq("max-age=100, public")
    
  end

  it 'should only cache responses when requested' do
    get :pages, :id => 328598
    response.header['Cache-Control'].should == nil
    get :pages, :id => 328598, :cache_ttl => 100
    response.header['Cache-Control'].should == 'max-age=100, public'
  end

  it 'should not add cache headers when there is an error' do
    get :pages, :id => 5625468165
    response.status.should == 404
    response.header['Cache-Control'].should == nil
    get :pages, :id => 1234567890, :cache_ttl => 100
    response.header['Cache-Control'].should == nil
  end
end
