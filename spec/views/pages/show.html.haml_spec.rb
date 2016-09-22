require "rails_helper"

RSpec.describe "pages/show" do
  let(:resource) do
    instance_double("Resource", id: 64333, name: "Short Res Name")
  end

  let(:page) do
    parent = instance_double("Node", ancestors: [], name: "Parent Taxon",
      canonical_form: "Parent Taxon", page_id: 653421)
    node = instance_double("Node", ancestors: [parent], name: "SomeTaxon")
    lic1 = instance_double("License", name: "Image license name")
    lic2 = instance_double("License", name: "Article license name")
    image1 = instance_double("Medium", license: lic1, owner: "Owner 1", id: 1,
      large_size_url: "some_url_580_360.jpg", small_icon_url: "no_matter",
      original_size_url: "no_matter",
      name: "Awesome First Image")
    image2 = instance_double("Medium", license: lic1, owner: "Owner 2",
      small_icon_url: "no_matter", original_size_url: "no_matter", id: 2,
      large_size_url: "another_url_580_360.jpg", name: "Great Second Image")
    article = instance_double("Article", name: "Article Name", license: lic2,
      body: "Article body", owner: "Article owner")
    traits = [
      { predicate: "http://predic.ate/one", measurement: "657",
        units: "http://un.its/one", resource_id: resource.id },
      { predicate: "http://predic.ate/one", term: "http://te.rm/one" },
      { predicate: "http://predic.ate/two", literal: "literal trait value" } ]
    glossary = {
      "http://predic.ate/one" => instance_double("Uri", name: "Predicate One"),
      "http://predic.ate/two" => instance_double("Uri", name: "Predicate Two"),
      "http://un.its/one" => instance_double("Uri", name: "Units URI"),
      "http://te.rm/one" => instance_double("Uri", name: "Term URI")
    }
    instance_double("Page", id: 8293, name: "something common", native_node: node,
      scientific_name: "<i>Nice scientific</i>", media: [image1, image2],
      article: article, traits: traits, glossary: glossary,
      predicates: traits.map { |t| t[:predicate] },
      grouped_traits: traits.group_by { |t| t[:predicate] } )
  end

  before do
    assign(:page, page)
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

  it "adds the default size to the image src" do
    render
    expect(rendered).to match /some_url_580_360.jpg/
    expect(rendered).to match /another_url_580_360.jpg/
  end

  it "shows the ancestor names" do
    render
    expect(rendered).to match /Parent Taxon/
  end

  it "shows the article" do
    render
    expect(rendered).to match /Article license name/
    expect(rendered).to match /Article Name/
    expect(rendered).to match /Article body/
    expect(rendered).to match /Article owner/
  end

  it "shows the article section name if article name is missing" do
    expect(page).to receive(:article) { nil }
    render
    expect(rendered).not_to have_content(I18n.t(:page_article_header))
  end

  it "shows the predicates once each" do
    render
    # NOTE: have_content doesn't seem to work with traits: it creates
    # duplicates. Not sure why.
    expect(rendered).to match(/Predicate One/)
    expect(rendered).not_to match(/Predicate One.*Predicate One/)
    expect(rendered).to match(/Predicate Two/)
    expect(rendered).not_to match(/Predicate Two.*Predicate Two/)
  end

  it "shows measurements and units" do
    render
    expect(rendered).to match /657\s+Units URI/
  end

  it "shows terms" do
    render
    expect(rendered).to match /Term URI/
  end

  it "shows literal trait values" do
    render
    expect(rendered).to match /literal trait value/
  end

  it "shows resource names when available" do
    render
    expect(rendered).to match /Short Res Name/
  end
end
