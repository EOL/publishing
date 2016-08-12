require "rails_helper"

RSpec.describe "pages/show" do
  before do
    name = instance_double("Vernacular", string: "something common")
    scientific = instance_double("ScientificName",
      canonical_form: "<i>Nice scientific</i>")
    assign(:page, instance_double("Page", name: name,
      scientific_name: scientific))
  end
  it "shows the title" do
    render

    expect(rendered).to match /Something Common/
    expect(rendered).to match /Nice scientific/
  end
end
