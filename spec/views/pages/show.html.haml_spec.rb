require "rails_helper"

RSpec.describe "pages/show" do
  let(:resource) do
    create(:resource, id: 64333, name: "Short Res Name", url: nil)
  end
  let(:lic1) do
    instance_double("License", name: "Image license name")
  end
  let(:image1) do
    instance_double("Medium", license: lic1, owner: "Owner 1", id: 1,
      large_size_url: "some_url_580_360.jpg", medium_size_url: "img1_med.jpg",
      small_icon_url: "no_matter", original_size_url: "img1_full_size.jpg",
      name: "Awesome First Image")
  end
  let(:image2) do
    instance_double("Medium", license: lic1, owner: "Owner 2", id: 2,
      small_icon_url: "no_matter", original_size_url: "img2_full_size.jpg",
      large_size_url: "second_url_580_360.jpg", medium_size_url: "img2_med.jpg",
      name: "Great Second Image")
  end

  # NOTE: I think we'll eventually want to extract this into a nice class to
  # mock pages for views... but ATM we only need it once, here, so I'm leaving
  # it despite its gross size and complexity:
  let(:page) do
    parent = instance_double("Node", ancestors: [], name: "Parent Taxon",
      canonical_form: "Parent Taxon", page_id: 653421, has_breadcrumb?: true)
    node = instance_double("Node", ancestors: [parent], name: "SomeTaxon",
      children: [], resource: resource, has_breadcrumb?: true)
    lic2 = instance_double("License", name: "Article license name")
    article = instance_double("Article", name: "Article Name", license: lic2,
      body: "Article body", owner: "Article owner", rights_statement: nil,
      bibliographic_citation: nil, location: nil, attributions: [],
      source_url: nil, resource: resource, resource_pk: "1234")
    sci_name = instance_double("ScientificName", node: node,
      italicized: "<i>Nice scientific</i>",
      taxonomic_status: TaxonomicStatus.synonym)
    vernacular = instance_double("Vernacular", string: "something common",
      language: Language.english, is_preferred?: true, node: node,
      is_preferred_by_resource: true)
    traits = [
      { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
        measurement: "657", units: { uri: "http://un.its/one",
        name: "Units URI" }, resource_id: resource.id },
      { predicate: { uri: "http://predic.ate/one", name: "Predicate One" },
        object_term: { uri: "http://te.rm/one", name: "Term URI" } },
      { predicate: { uri: "http://predic.ate/two", name: "Uri" },
        literal: "literal trait value" } ]
    glossary = {
      "http://predic.ate/one" => { name: "Predicate One" },
      "http://predic.ate/two" => { name: "Predicate Two" },
      "http://un.its/one" => { name: "Units URI" },
      "http://te.rm/one" => { name: "Term URI" }
    }

    instance_double("Page",
      id: 8293,
      articles: [article],
      articles_count: 1,
      nodes_count: 1,
      glossary: glossary,
      grouped_traits: traits.group_by { |t| t[:predicate][:uri] },
      habitats: "",
      iucn_status_key: :lc,
      is_it_extinct?: false,
      is_it_marine?: false,
      literature_and_references_count: 0,
      map?: false,
      media_count: 2,
      nodes: [node],
      name: vernacular.string,
      names_count: 2,
      native_node: node,
      occurrence_map?: false,
      predicates: traits.map { |t| t[:predicate][:uri] },
      scientific_name: sci_name.italicized,
      scientific_names: [sci_name],
      top_image: image1,
      traits: traits,
      traits_count: 3,
      vernaculars: [vernacular]
    )
  end

  before do
    assign(:page, page)
    media = [image1, image2]
    allow(media).to receive(:total_pages) { 1 } # kaminari
    allow(media).to receive(:current_page) { 1 } # kaminari
    allow(media).to receive(:limit_value) { 2 } # kaminari
    assign(:media, media)
    assign(:resources, { resource.id => resource })
  end

  it "shows the title" do
    render
    expect(rendered).to match /Something Common/
    expect(rendered).to match /Nice scientific/
  end

  it "shows the top images' metadata" do
    render
    # NOTE: these don't work with "have content" because they are stored in data
    # attributes.
    expect(rendered).to match /Image license name/
    expect(rendered).to match /Owner 1/
    expect(rendered).to match /Owner 2/
    expect(rendered).to match /Awesome First Image/
    expect(rendered).to match /Great Second Image/
  end

  it "shows the medium size images" do
    render
    expect(rendered).to match /img1_med.jpg/
    expect(rendered).to match /img2_med.jpg/
  end

  it "allows original size images (lightbox)" do
    render
    expect(rendered).to match /img1_full_size.jpg/
    expect(rendered).to match /img2_full_size.jpg/
  end

  it "shows the ancestor names" do
    render
    expect(rendered).to match /Parent Taxon/
  end

  # TODO! Articles were moved to another (Ajaxy) view, so this won't work now.
  # it "shows the article" do
  #   render
  #   expect(rendered).to match /Article license name/
  #   expect(rendered).to match /Article Name/
  #   expect(rendered).to match /Article body/
  #   expect(rendered).to match /Article owner/
  # end
  #
  # it "shows the article section name if article name is missing" do
  #   expect(page).to receive(:article) { nil }
  #   render
  #   expect(rendered).not_to have_content(I18n.t(:page_article_header))
  # end

  # These only apply when traits tab is shown:
  # it "shows the predicates once each" do
  #   render
  #   # NOTE: have_content doesn't seem to work with traits: it creates
  #   # duplicates. Not sure why.
  #   expect(rendered).to match(/Predicate One/)
  #   expect(rendered).not_to match(/Predicate One.*Predicate One/)
  #   expect(rendered).to match(/Predicate Two/)
  #   expect(rendered).not_to match(/Predicate Two.*Predicate Two/)
  # end
  #
  # it "shows measurements and units" do
  #   render
  #   expect(rendered).to match /657\s+Units URI/
  # end
  #
  # it "shows terms" do
  #   render
  #   expect(rendered).to match /Term URI/
  # end
  #
  # it "shows literal trait values" do
  #   render
  #   expect(rendered).to match /literal trait value/
  # end
  #
  # it "shows resource names when available" do
  #   render
  #   expect(rendered).to match /Short Res Name/
  # end
end
