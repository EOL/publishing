require "rails_helper"

RSpec.describe "traits/show" do
  before do
    # TODO: Would be nice to have helpers/mocks for this kind of thing.
    uri = instance_double("Uri", name: "Trait One",
      definition: "Defined thusly")
    units = instance_double("Uri", uri: "http://un.its/one", name: "Unit URI")
    term = instance_double("Uri", uri: "http://te.rm/one", name: "Term URI")

    page1_name = instance_double("Vernacular", string: "page 1 vern")
    page1_sci_name = instance_double("ScientificName",
      canonical_form: "<i>Page 1 Canon<i/>")
    page2_name = instance_double("Vernacular", string: "page 2 vern")
    page2_sci_name = instance_double("ScientificName",
      canonical_form: "<i>Page 2 Canon<i/>")

    page1_icon = instance_double("Medium", base_url: "http://this/path",
      name: "Page 1 Icon")

    page1 = instance_double("Page", id: 1234, name: page1_name,
      scientific_name: page1_sci_name, top_images: [page1_icon])
    page2_no_icon = instance_double("Page", id: 2345, name: page2_name,
      scientific_name: page2_sci_name, top_images: [])

    traits =
      [ { page_id: 1234, measurement: "657", units: units.uri },
        { page_id: 2345, term: term.uri },
        { page_id: 2345, literal: "literal trait value" } ]
    glossary = { units.uri => units, term.uri => term }

    assign(:uri, uri)
    assign(:traits, traits)
    assign(:pages, { 1234 => page1, 2345 => page2_no_icon })
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

  it "shows names for all pages" do
    render
    expect(rendered).to match /Page 1 Vern/
    expect(rendered).to match /Page 2 Vern/
    expect(rendered).to match /Page 1 Canon/
    expect(rendered).to match /Page 2 Canon/
  end

  it "shows icons for pages that have them" do
    render
    expect(rendered).to match "http://this/path_88_88.jpg"
  end

  # Err... a bit tricky, need to parse the output, not interesting/useful enough
  # right now.
  it "shows no icon for pages that do NOT have one"

  it "shows all trait values" do
    render
    expect(rendered).to match /Unit URI/
    expect(rendered).to match /Term URI/
    expect(rendered).to match /literal trait value/
  end
end
