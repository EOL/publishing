require 'rails_helper'

RSpec.describe Section do

  it "has brief summary" do
    Section.brief_summary
    expect(Section.where(name: "brief_summary")).not_to be_nil
  end
  
  it "has comprehensive description" do
    Section.comprehensive_description
    expect(Section.where(name: "comprehensive_description")).not_to be_nil
  end
  
  it "has distribution" do
    Section.distribution
    expect(Section.where(name: "distribution")).not_to be_nil
  end
  
end