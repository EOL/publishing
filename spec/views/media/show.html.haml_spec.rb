require "rails_helper"

RSpec.describe "media/show" do
  # NOTE: as usual, it's linked, so easier not to mock:
  let(:medium) { build(:medium, description: "not empty") }

  before do
    allow(medium).to receive(:large_size_url) { "this_guy.jpg" }
    assign(:medium, medium)
    render
  end

  it { expect(rendered).to have_content(medium.name) }
  it { expect(rendered).to have_content(medium.description) }
  it "shows the large image" do
    expect(rendered).to match("this_guy.jpg")
  end
end
