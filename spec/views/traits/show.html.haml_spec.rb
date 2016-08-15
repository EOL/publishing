require "rails_helper"

RSpec.describe "traits/show" do
  before do
    uri = instance_double("Uri", name: "Trait One",
      definition: "Defined thusly")
    units = instance_double("Uri", uri: "http://un.its/one", name: "Unit URI")
    term = instance_double("Uri", uri: "http://te.rm/one", name: "Unit URI")

    # YOU WERE HERE: you need a page with no icon, then you need to spec that
    # all of these things get rendered. Also check that the term / units are
    # rendered.
    page1 = instance_double("Page", id: 1234, name: "Unit URI")
    page2 = instance_double("Page", uri: "http://te.rm/one", name: "Unit URI")
    page3 = instance_double("Page", uri: "http://te.rm/one", name: "Unit URI")

    traits =
      [ { page_id: "1234", measurement: "657", units: "http://un.its/one" },
        { page_id: "2345", term: "http://te.rm/one" },
        { page_id: "2345", literal: "literal trait value" } ]
    glossary = { "http://un.its/one" => units, "http://te.rm/one" => term }

    assign(:uri, uri)
    assign(:traits, traits)
    assign(:pages, pages)
    assign(:glossary, glossary)
  end

  it "shows the title" do
    render
    expect(rendered).to match /Trait One/
  end

  it "shows the definition" do
    render
    expect(rendered).to match /Defined thusly/
  end

  it "shows "
end
