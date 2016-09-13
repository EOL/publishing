require "rails_helper"

RSpec.describe "traits/show" do
  let(:page1) { create(:page) }
  let(:page2) { create(:page) }

  before do
    # TODO: Would be nice to have helpers/mocks for this kind of thing.
    uri = instance_double("Uri", name: "Trait One",
      definition: "Defined thusly")
    units = instance_double("Uri", uri: "http://un.its/one", name: "Unit URI")
    term = instance_double("Uri", uri: "http://te.rm/one", name: "Term URI")

    resource = instance_double("Resource", id: 65422, name: "Resource Name")

    traits =
      [ { page_id: 1234, measurement: "657", units: units.uri, id: "1:1",
          resource_id: resource.id },
        { page_id: 2345, term: term.uri, resource_id: resource.id, id: "1:2" },
        { page_id: 2345, literal: "literal trait value", id: "1:3",
          resource_id: resource.id } ]

    glossary = { units.uri => units, term.uri => term }

    assign(:uri, uri)
    assign(:traits, traits)
    assign(:pages, { 1234 => page1, 2345 => page2 })
    assign(:glossary, glossary)
    assign(:resources, { 65422 => resource })
  end

  it "shows the title" do
    render
    expect(rendered).to match /Trait One/
  end

  it "shows the definition" do
    render
    expect(rendered).to match /Defined thusly/
  end

  it "shows canonical names for all pages" do
    render
    expect(rendered).to match /#{page1.scientific_name}/
    expect(rendered).to match /#{page2.scientific_name}/
  end

  it "shows all names (in titlecase)" do
    expect(page1).to receive(:name).at_least(1).times { "this oneName" }
    expect(page2).to receive(:name).at_least(1).times { "thatName too" }
    render
    expect(rendered).to match /#{page1.scientific_name}/
    expect(rendered).to match /#{page2.scientific_name}/
    # TODO: we don't really want titlecase to break up those words, because some
    # languages may want to allow middle-of-the-word caps.
    expect(rendered).to have_content("This One Name")
    expect(rendered).to have_content("That Name Too")
  end

  it "shows icons for pages that have them" do
    image = instance_double("Medium",
      small_icon_url: "http://this/path_88_88.jpg")
    expect(page1).to receive(:top_image) { image }
    render
    expect(rendered).to match "http://this/path_88_88.jpg"
  end

  it "shows icon for pages" do
    image = instance_double("Medium",
      small_icon_url: "http://this/path_88_88.jpg")
    expect(page1).to receive(:top_image) { image }
    render
    expect(rendered).to have_selector("tr#1\\:1 th.trait-table-image img")
  end

  it "shows NO icon for pages that do NOT have one" do
    render
    expect(rendered).not_to have_selector("tr#1\\:2 th.trait-table-image img")
  end

  it "shows all trait values" do
    render
    expect(rendered).to match /Unit URI/
    expect(rendered).to match /Term URI/
    expect(rendered).to match /literal trait value/
  end

  it "shows the resource's short name" do
    render
    expect(rendered).to match /Resource Name/
  end
end
