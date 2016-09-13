require "rails_helper"

RSpec.describe "collections/show" do
  context "(with robust collection)" do
    # Easier to create pages (which are complex) than to double them:
    let(:page1) { create(:page) }
    let(:page2) { create(:page) }

    before do
      item1 = instance_double("CollectionItem", item: page1)
      item2 = instance_double("CollectionItem", item: page2)
      collection = instance_double("Collection", collection_items: [item1, item2],
        name: "Col Name 1", description: "Col Description Here")
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
      expect(rendered).to match(/#{page1.name}/)
      expect(rendered).to match(/#{page2.name}/)
    end

    it "shows the scientific names of all collected pages" do
      render
      expect(rendered).to match(/#{page1.scientific_name}/)
      expect(rendered).to match(/#{page2.scientific_name}/)
    end
  end

  context "(with empty collection)" do
    before do
      collection = instance_double("Collection", collection_items: [],
        name: "Col Name Again", description: nil)
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

    it "shows an edit button" do
      render
      expect(rendered).to have_selector("a", text: "edit")
    end
  end
end
