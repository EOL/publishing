require "rails_helper"

RSpec.describe "terms/show" do
  let(:page1) { create(:page) }
  let(:page2) { create(:page) }

  before do
    # TODO: Would be nice to have helpers/mocks for this kind of thing.
    uri = { name: "Trait One", uri: "http://blah/blah",
      definition: "Defined thusly" }
    units = { uri: "http://un.its/one", name: "Unit URI" }
    term = { uri: "http://te.rm/one", name: "Term URI" }

    resource = instance_double("Resource", id: 65422, name: "Resource Name")

    data =
      [ { page_id: 1234, measurement: "657", units: units, id: "1:1",
          resource_id: resource.id },
        { page_id: 2345, object_term: term, resource_id: resource.id, id: "1:2" },
        { page_id: 2345, literal: "literal data value", id: "1:3",
          resource_id: resource.id } ]

    glossary = { units[:uri] => units, term[:uri] => term }

    assign(:term, uri)
    assign(:grouped_data, Kaminari.paginate_array(data).page(1))
    assign(:pages, { 1234 => page1, 2345 => page2 })
    assign(:glossary, glossary)
    assign(:resources, { 65422 => resource })
    allow(view).to receive(:is_admin?) { false }
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
    expect(page1).to receive(:medium) { image }
    render
    expect(rendered).to match "http://this/path_88_88.jpg"
  end

  # it "shows icon for pages" do
  #   image = instance_double("Medium",
  #     small_icon_url: "http://this/path_88_88.jpg")
  #   expect(page1).to receive(:medium) { image }
  #   render
  #   # We're not actually testing the image here, because it's rendered in a
  #   # helper and that gets hairy with tests ... but the div should be there!:
  #   expect(rendered).to have_selector("tr#1\\:1 th.data-table-image")
  # end

  it "shows NO icon for pages that do NOT have one" do
    render
    expect(rendered).not_to have_selector("tr#1\\:2 th.data-table-image img")
  end

  it "shows all data values" do
    render
    expect(rendered).to match /Unit URI/
    expect(rendered).to match /Term URI/
    expect(rendered).to match /Literal data value/ # NOTE initial cap...
  end

  it "shows the resource's short name" do
    render
    expect(rendered).to match /Resource Name/
  end
end
