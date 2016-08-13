require "rails_helper"

RSpec.describe "pages/show" do
  before do
    name = instance_double("Vernacular", string: "something common")
    lic1 = instance_double("License", name: "Image license name")
    lic2 = instance_double("License", name: "Article license name")
    image1 = instance_double("Medium", license: lic1, owner: "Owner 1",
      base_url: "some_url", name: "Image Name 1")
    image2 = instance_double("Medium", license: lic1, owner: "Owner 2",
      base_url: "some_url", name: "Image Name 2")
    scientific = instance_double("ScientificName",
      canonical_form: "<i>Nice scientific</i>")
    article = instance_double("Article", name: "Article Name", license: lic1,
      body: "Article body", owner: "Article owner")
    assign(:page, instance_double("Page", name: name,
      scientific_name: scientific, top_images: [image1, image2]),
      top_articles: [article])
  end
  it "shows the title" do
    render
    expect(rendered).to match /Something Common/
    expect(rendered).to match /Nice scientific/
  end
  it "shows the top images' metadata" do
    render
    expect(rendered).to match /Image license name/
    expect(rendered).to match /Owner 1/
    expect(rendered).to match /Owner 2/
    expect(rendered).to match /Image Name 1/
    expect(rendered).to match /Image Name 2/
  end

  it "adds the default size to the image src" do
    render
    expect(rendered).to match /some_url_580_360.jpg/
  end

  it "shows the article" do
    render
    expect(rendered).to match /Article license name/
    expect(rendered).to match /Article Name/
    expect(rendered).to match /Article body/
    expect(rendered).to match /Article owner/
  end
  
  it "shows the article section name if article name is missing"

end
