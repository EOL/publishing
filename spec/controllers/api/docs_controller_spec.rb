require 'rails_helper'
RSpec.describe ApiController do

  it 'there should be 3 API methods' do
    Api::METHODS.length.should == 3
  end
  
  it 'should load the class corresponding to each API method' do
    Api::METHODS.each do |method_name|
      latest_version_method = Api.default_version_of(method_name)
      get method_name
      assigns[:api_method].should == latest_version_method
    end
  end
end