require "rails_helper"

RSpec.describe "media/show" do
  let(:page1) { create(:page) } # Involves a link
  let(:page2) { create(:page) } # Involves a link
  let(:medium) { build(:medium, description: "not empty") }
  let(:page_content) { double(:page_content, page: page1, page_id: page1.id) }

  before do
    allow(medium).to receive(:large_size_url) { "this_guy.jpg" }
    allow(medium).to receive(:page_contents) { [page_content] }
    allow(medium).to receive(:associations) { [page2] }
    allow(medium).to receive(:page_icons) { [1,2,3] }
    assign(:medium, medium)
    render
  end

  it { expect(rendered).to have_content(medium.name) }
  it { expect(rendered).to have_content(medium.description) }
  it { expect(rendered).to have_content(medium.license.name) }
  it { expect(rendered).to match("this_guy.jpg") }
  it { expect(rendered).to match(page1.name) }
  it { expect(rendered).to match(page2.name) }
  it { expect(rendered).to have_content("icon 3 times") }
end
