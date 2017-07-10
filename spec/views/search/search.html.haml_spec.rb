require "rails_helper"

RSpec.describe "search/search" do
  before do
    allow(view).to receive(:is_admin?) { false }
  end

  context "with page results" do
    before do
      name = instance_double("Vernacular", string: "a vernacular name")
      english = instance_double("English", code: "eng")
      another_name = instance_double("Vernacular",
        string: "another common name", language: english)
      nonmatching_name = instance_double("Vernacular",
        string: "name that doesnt match", language: english)
      lic = instance_double("License", name: "Image license name")
      rank = instance_double("Rank", name: "Whatever", treat_as: "r_class")
      parent = instance_double("Node", ancestors: [], page_id: 342356,
        canonical_form: "Ancestor name", has_breadcrumb?: true)
      node = instance_double("Node", ancestors: [parent], has_breadcrumb?: false, rank: rank)
      scientific_names = [instance_double("ScientificName",
        canonical_form: "<i>Our scientific</i>")]
      partner = instance_double("Partner", short_name: "Partner One")
      resources = [instance_double("Resource", name: "Resource One",
        partner: partner)]
      page = create(:page)
      allow(page).to receive(:name) { "a vernacular name" }
      allow(page).to receive(:icon) { "some_image_url_88_88.jpg" }
      allow(page).to receive(:scientific_name) { scientific_names.first.canonical_form }
      allow(page).to receive(:scientific_names) { scientific_names }
      allow(page).to receive(:native_node) { node }
      highlights = {
        scientific_name: "Our scientific",
        preferred_vernacular_strings: "a vernacular name",
        vernacular_strings: "another **common** name",
        synonyms: nil,
        providers: "Resource One",
        resource_pks: nil
      }
      allow(page).to receive(:search_highlights) { highlights }
      allow(page).to receive(:resources) { resources }
      search_results = fake_search_results([page])
      assign(:pages, search_results)
      assign(:empty, false)
      assign(:q, "common")
      render
    end

    # NOTE the titlized cases: }
    it { expect(rendered).to match /Our scientific/ }
    it { expect(rendered).to match /Ancestor name/ }
    it { expect(rendered).to match /A Vernacular Name/ }
    it { expect(rendered).to match /another \*\*common\*\* name/m }
    # it { expect(rendered).to match /another **common** name\&nbsp\;\(eng\)/m }
    it { expect(rendered).not_to match /name that doesnt match/i }
    it { expect(rendered).to match /some_image_url_88_88.jpg/ }
  end

  context "with no results" do
    before do
      search_results = fake_search_results([])
      assign(:pages, search_results)
      assign(:empty, true)
      assign(:q, "nothing")
      render
    end

    it { expect(rendered).to match(/No results found for.*nothing/) }
  end

  context "with collection results" do
    before do
      collection = build(:collection, name: "yo dude",
        description: "a really LONG description that should be truncated "\
          "enough that you dont see the capitalized word when searching, dude")
      search_results = fake_search_results([collection])
      assign(:collections, search_results)
      assign(:empty, false)
      assign(:q, "Yo **dude**")
      highlights = {
        name: nil,
        description: "searching, **dude**"
      }
      allow(collection).to receive(:search_highlights) { highlights }
      render
    end

    # NOTE the titlized case:
    it { expect(rendered).to have_content("Yo Dude") }
    it { expect(rendered).to match(/Yo [*]+dude[*]+/) }
    it { expect(rendered).to match(/searching, [*]+dude[*]+/) }
    it { expect(rendered).not_to match(/LONG/) }
  end

  context "with media results" do
    before do
      # Create to avoid an error on the link, sigh:
      medium = create(:medium, resource_pk: "this_earthling_was_here",
        name: "greetings earthling", owner: "A random earthling",
        description: "a really LONG description that should be lost so "\
          "that you dont see the capitalized word when searching, earthling")
      allow(medium).to receive(:medium_icon_url) { "some_url_here.jpg" }
      search_results = fake_search_results([medium])
      assign(:media, search_results)
      assign(:empty, false)
      highlights = {
        name: "Greetings **earthling**",
        description: "searching, **earthling**",
        resource_pk: "this_**earthling**_was_here"
      }
      allow(medium).to receive(:search_highlights) { highlights }
      assign(:q, "earthling")
      render
    end

    it { expect(rendered).to have_content("A random earthling") }
    it { expect(rendered).to match(/Greetings \*\*Earthling\*\*/) }
    it { expect(rendered).to match(/this_\*\*earthling\*\*_was/) }
    it { expect(rendered).to match(/searching, \*\*earthling\*\*/) }
    it { expect(rendered).to match(/some_url_here.jpg/) }
    it { expect(rendered).not_to match(/LONG/) }
  end
end
