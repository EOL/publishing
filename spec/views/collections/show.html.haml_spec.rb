require "rails_helper"

RSpec.describe "collections/show" do
  before do
    allow(view).to receive(:policy).and_return(double("some policy", update?: false))
  end

  context "(with robust collection)" do
    let(:medium1) { create(:medium) }
    let(:medium2) { create(:medium) }

    before do
      item1 = instance_double("CollectionItem", item: medium1)
      item2 = instance_double("CollectionItem", item: medium2)
      collection = instance_double("Collection", collection_items: [item1, item2],
        collected_pages: [], name: "Col Name 1",
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

    it "shows the names of all collected items" do
      render
      expect(rendered).to have_content(medium1.name)
      expect(rendered).to have_content(medium2.name)
    end

    it "shows the icons of all collected items" do
      render
      expect(rendered).to have_selector("img[src*='#{medium1.icon}']")
      expect(rendered).to have_selector("img[src*='#{medium2.icon}']")
    end
  end

  context "(with empty collection)" do
    before do
      collection = instance_double("Collection", collection_items: [],
        collected_pages: [], name: "Col Name Again", description: nil)
      assign(:collection, collection)
    end

    it "shows the name" do
      render
      expect(rendered).to have_content("Col Name Again")
    end

    it "shows a message about missing items" do
      render
      expect(rendered).to match(/#{I18n.t(:collection_items_empty).gsub(/"/, "&quot;")}/)
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
