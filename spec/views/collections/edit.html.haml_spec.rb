require "rails_helper"

RSpec.describe "collections/edit" do
  let(:page) { create(:page) }
  let(:collected_page) { create(:collected_page, page: page) }

  let(:collection) { create(:collection, collected_pages: [collected_page]) }

  before do
    assign(:collection, collection)
    allow(view).to receive(:policy).and_return(double("some policy", update?: false))
  end

  context "with simple pages" do
    before do
      render
    end

    it { expect(rendered).to have_selector("form#edit_collection_#{collection.id}") }
    it { expect(rendered).to have_selector("input#collection_name") }
    it { expect(rendered).to have_selector("textarea#collection_description") }
    it { expect(rendered).to match(collected_page.name) }
    it { expect(rendered).to match(collected_page.scientific_name_string) }
    it { expect(rendered).to match(I18n.t(:collected_pages_title)) }
  end

  context "with a page having multiple images" do
    let(:image1) { instance_double("Medium", id: 1230,
        small_icon_url: "sm_ico1.jpg", medium_icon_url: "med_ico1.jpg" ) }
    let(:image2) { instance_double("Medium", id: 1231,
        small_icon_url: "sm_ico2.jpg", medium_icon_url: "med_ico2.jpg" ) }

    before do
      allow(page).to receive(:media) { [image1, image2] }
      render
    end

    it "has a radio button for each image" do
      expect(rendered).to have_selector("input#collection_collected_pages_attributes_0_medium_id_#{image1.id}")
      expect(rendered).to have_selector("input#collection_collected_pages_attributes_0_medium_id_#{image2.id}")
    end
  end
end
