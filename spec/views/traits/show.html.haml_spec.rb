require "rails_helper"

RSpec.describe "traits/show" do
  before do
    uri = instance_double("Uri", name: "Trait One",
      definition: "Defined thusly")
    assign(:uri, uri)
  end
  
  it "shows the title" do
    render
    expect(rendered).to match /Trait One/
    expect(rendered).to match /Defined thusly/
  end
end
