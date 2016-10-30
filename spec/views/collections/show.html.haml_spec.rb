require "rails_helper"

RSpec.describe "collections/show" do
  before do
    allow(view).to receive(:policy).and_return(double("some policy", update?: false))
  end

  context "(with robust collection)" do
    let(:collection1) { create(:medium) }
    let(:collection2) { create(:medium) }
    let(:page) { create(:page) }
    let(:collected_page) { create(:collected_page, page: page) }

    before do
      allow(page).to receive(:icon) { "some_icon" }
      allow(page).to receive(:name) { "funName" }
      collection = instance_double("Collection",
        collections: [collection1, collection2],
        collected_pages: [collected_page], 
        id: 1,
        name: "Col Name 1",
        description: "Col Description Here")
      assign(:collection, collection)
    end

    it "shows the name" do
      render
      expect(rendered).to have_content("Col Name 1")
    end

    it "shows the description" do
      render
      expect(rendered).to have_content("Col Description Here")
    end

    it "shows the names of all collected associations and pages" do
      render
      expect(rendered).to have_content(collection1.name)
      expect(rendered).to have_content(collection2.name)
      # NOTE: using #match because it contains italics:
      expect(rendered).to match(collected_page.scientific_name_string)
      # NOTE: titleize'd:
      expect(rendered).to have_content("Fun Name")
    end

    it "shows the icons of all collected associations" do
      render
      expect(rendered).to have_selector("img[src*='#{collection1.icon}']")
      expect(rendered).to have_selector("img[src*='#{collection2.icon}']")
      expect(rendered).to have_selector("img[src*='#{page.icon}']")
    end

    context 'collection search' do 
      it 'has collection search input' do
        render
        expect(rendered).to have_selector("div[class='input-group collection_search']")
      end
    end
  end

  context "(with empty collection)" do
    before do
      collection = instance_double("Collection", collections: [],
        collected_pages: [], name: "Col Name Again", description: nil, id: 2)
      assign(:collection, collection)
      render
    end

    it { expect(rendered).to have_content("Col Name Again") }
    it { expect(rendered).to match(/#{I18n.t(:collection_pages_empty).gsub("\"", "&quot;")}/) }
    it { expect(rendered).to match(/#{I18n.t(:collection_associations_empty).gsub("\"", "&quot;")}/) }
    it { expect(rendered).not_to have_selector("a", text: "edit") }

    context "when owned by the user" do
      it "shows an edit button" do
        expect(view).to receive(:policy).and_return(double("some policy", update?: true))
        render
        expect(rendered).to have_selector("a", text: "edit")
      end
    end
  end
end
