require 'rails_helper'

RSpec.describe Node do
  # context "no vernaculars" do
    # let(:node) { create(:node) }
    # it "has scientific name" do
      # expect(node.name).to eq(node.scientific_name)
    # end 
  # end
   
  context "with vernaculars" do
    let(:ver) { create(:vernacular, is_preferred: true) }
    
    it "uses preloaded preferred vernaculars" do
      expect(ver.node.name).to eq(ver.string)
    end
  
    
   
  end
end