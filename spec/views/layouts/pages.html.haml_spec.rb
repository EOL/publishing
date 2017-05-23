require "rails_helper"

RSpec.describe "layouts/pages" do

  let(:resource) do
    create(:resource, id: 64333, name: "Short Res Name", url: nil)
  end

  let(:rank) { create(:rank) }

  let(:image1) do
    instance_double("Medium", owner: "(c) Owner 1", id: 1,
      large_size_url: "some_url_580_360.jpg", medium_size_url: "img1_med.jpg",
      small_icon_url: "no_matter", original_size_url: "img1_full_size.jpg",
      name: "Awesome First Image", resource: resource)
  end

  let(:page) do
    double_page(rank: rank, resource: resource, media: [image1])
  end

  before do
    allow(view).to receive(:current_user) { }
    allow(view).to receive(:is_admin?) { false }
    assign(:page, page)
  end

  it "shows a media subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/media")
    expect(rendered).to have_content /1\s*Media/
  end

  it "shows a data subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/traits")
    expect(rendered).to have_content /3\s*Traits/
  end

  it "shows a details subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/details")
    expect(rendered).to have_content /1\s*Details/
  end

  it "shows a classification subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/classifications")
    expect(rendered).to have_content /1\s*Classification/
  end

  it "shows a names subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/names")
    expect(rendered).to have_content /2\s*Names/
  end

  it "shows a literature_and_references subtab" do
    render
    expect(rendered).to have_link(href: "/pages/#{page.id}/literature_and_references")
    expect(rendered).to have_content /3\s*References/
  end
end
