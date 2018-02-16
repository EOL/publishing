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
    allow(view).to receive(:main_container?) { true }
    assign(:page, page)
  end

  it "shows a media subtab" do
    render
    expect(rendered).to have_link("media", href: page_media_path(page))
  end

  it "shows a data subtab" do
    render
    expect(rendered).to have_link("data", href: page_data_path(page))
  end

  it "shows a detail subtab" do
    render
    expect(rendered).to have_link("detail", href: page_details_path(page))
  end

  it "shows a names subtab" do
    render
    expect(rendered).to have_link("names", href: page_names_path(page))
  end

  it "shows a literature_and_references subtab" do
    render
    expect(rendered).to have_link(
      "literature & references",
      href: page_literature_and_references_path(page)
    )
  end
end
