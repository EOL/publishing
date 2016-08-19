require "rails_helper"

RSpec.describe "search/search" do
  context "with results" do
    before do
      name = instance_double("Vernacular", string: "a common name")
      lic = instance_double("License", name: "Image license name")
      image1 = instance_double("Medium", license: lic, owner: "Owned Here",
        small_icon_url: "some_image_url_88_88.jpg", name: "Thumbnail Image")
      page = instance_double("Page", name: name, top_images: [image1],
        scientific_name: "<i>Our scientific</i>")
      search_results = double("Sunspot::Search", results: [page])
      assign(:pages, search_results)
    end

    it "shows the names" do
      render
      # note the titlecase:
      expect(rendered).to match /A Common Name/
      expect(rendered).to match /Our scientific/
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
