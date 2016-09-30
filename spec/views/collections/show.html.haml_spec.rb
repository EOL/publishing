require "rails_helper"

RSpec.describe "collections/show" do
  before do
    allow(view).to receive(:policy).and_return(double("some policy", update?: false))
  end

  context "(with robust collection)" do
    let(:medium1) { create(:medium) }
    let(:medium2) { create(:medium) }
    let(:page) { create(:page) }
    let(:collected_page) { create(:collected_page, page: page) }

    before do
      item1 = instance_double("CollectionItem", item: medium1)
      item2 = instance_double("CollectionItem", item: medium2)
      allow(page).to receive(:icon) { "some_icon" }
      allow(page).to receive(:name) { "funName" }
      collection = instance_double("Collection", collection_associations: [item1, item2],
        collected_pages: [collected_page], name: "Col Name 1",
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

    it "shows the names of all collected items and pages" do
      render
      expect(rendered).to have_content(medium1.name)
      expect(rendered).to have_content(medium2.name)
      # NOTE: using #match because it contains italics:
      expect(rendered).to match(collected_page.scientific_name_string)
      # NOTE: titleize'd:
      expect(rendered).to have_content("Fun Name")
    end

    it "shows the icons of all collected items" do
      render
      expect(rendered).to have_selector("img[src*='#{medium1.icon}']")
      expect(rendered).to have_selector("img[src*='#{medium2.icon}']")
      expect(rendered).to have_selector("img[src*='#{page.icon}']")
    end
  end

  context "(with empty collection)" do
    before do
      collection = instance_double("Collection", collection_associations: [],
        collected_pages: [], name: "Col Name Again", description: nil)
      assign(:collection, collection)
    end

    it "shows the name" do
      render
      expect(rendered).to have_content("Col Name Again")
    end

    it "shows a message about missing items" do
      render
      expect(rendered).to match(/#{I18n.t(:collection_associations_empty).gsub(/"/, "&quot;")}/)
    end

    it "does NOT show an edit button" do
      render
      expect(rendered).not_to have_selector("a", text: "edit")
    end

    context "when owned by the user" do
      it "shows an edit button" do
        expect(view).to receive(:policy).and_return(double("some policy", update?: true))
        render
        expect(rendered).to have_selector("a", text: "edit")
      end
    end
  end
end
