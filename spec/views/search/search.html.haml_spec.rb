require "rails_helper"

RSpec.describe "search/search" do
  context "with results" do
    before do
      name = instance_double("Vernacular", string: "a common name")
      english = instance_double("English", code: "eng")
      another_name = instance_double("Vernacular",
        string: "another common name", language: english)
      nonmatching_name = instance_double("Vernacular",
        string: "name that doesnt match", language: english)
      lic = instance_double("License", name: "Image license name")
      parent = instance_double("Node", ancestors: [], page_id: 342356,
        canonical_form: "Ancestor name")
      node = instance_double("Node", ancestors: [parent])
      scientific_names = [instance_double("ScientificName",
        canonical_form: "<i>Our scientific</i>")]
      partner = instance_double("Partner", short_name: "Partner One")
      resources = [instance_double("Resource", name: "Resource One",
        partner: partner)]
      page = create(:page)
      allow(page).to receive(:name) { "a common name" }
      allow(page).to receive(:icon) { "some_image_url_88_88.jpg" }
      allow(page).to receive(:scientific_name) { scientific_names.first.canonical_form }
      allow(page).to receive(:scientific_names) { scientific_names }
      allow(page).to receive(:native_node) { node }
      allow(page).to receive(:vernaculars) { [name, another_name, nonmatching_name] }
      allow(page).to receive(:resources) { resources }
      search_results = double("Sunspot::Search", results: [page])
      assign(:pages, search_results)
      assign(:empty, false)
      assign(:q, "common")
    end

    it "shows the scientific name" do
      render
      # note the titlecase:
      expect(rendered).to match /Our scientific/
    end

    it "shows the ancestor names" do
      render
      expect(rendered).to match /Ancestor name/
    end

    it "shows the common name with matches in title case" do
      render
      expect(rendered).to match /A <mark>Common<\/mark> Name/
    end

    it "shows other vernaculars where the name matches (with language)" do
      render
      expect(rendered).to match /another <mark>common<\/mark> name\&nbsp\;\(eng\)/m
    end

    it "does NOT show other vernaculars without matches" do
      render
      expect(rendered).not_to match /name that doesnt match/i
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
      assign(:empty, true)
      assign(:q, "nothing")
    end

    it "shows a message" do
      render
      expect(rendered).to match /No results found for.*nothing/
    end
  end
end
