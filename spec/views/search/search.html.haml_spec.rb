require "rails_helper"

RSpec.describe "search/search" do
  context "with results" do
    before do
      name = instance_double("Vernacular", string: "a common name")
      lic = instance_double("License", name: "Image license name")
      parent = instance_double("Node", ancestors: [], page_id: 342356,
        canonical_form: "Ancestor name")
      node = instance_double("Node", ancestors: [parent])
      english = instance_double("English", code: "eng")
      scientific_names = [instance_double("ScientificName",
        canonical_form: "<i>Our scientific</i>")]
      partner = instance_double("Partner", short_name: "Partner One")
      resources = [instance_double("Resource", name: "Resource One",
        partner: partner)]
      image1 = instance_double("Medium", license: lic, owner: "Owned Here",
        small_icon_url: "some_image_url_88_88.jpg", name: "Thumbnail Image")
      page = instance_double("Page", name: name, top_images: [image1],
        scientific_name: scientific_names.first.canonical_form,
        scientific_names: scientific_names, native_node: node,
        vernaculars: [name], resources: resources)
      search_results = double("Sunspot::Search", results: [page])
      assign(:pages, search_results)
      assign(:q, "common")
    end

    it "shows the scientific name" do
      render
      # note the titlecase:
      expect(rendered).to match /Our scientific/
    end

    it "shows the highlighted common name in title case" do
      render
      expect(rendered).to match /A <b>Common<\/b> Name/
    end

    it "shows the icon" do
      render
      expect(rendered).to match /some_image_url_88_88.jpg/
    end
  end

  context "with no results" do
    before do
      search_results = double("Sunspot::Search", results: [])
      assign(:pages, search_results)
      allow(view).to receive(:query_string) { "something" }
    end

    it "shows a message" do
      render
      expect(rendered).to match /No results found for.*something/
    end
  end
end
