require "rails_helper"

RSpec.describe "collected_pages/new" do
  # NOTE: using a few non-doubles here for cleanliness. Forms need many fields
  # and mocking them is cluttered. I've doubled everything that it made sense to.
  before do
    allow(Language).to receive(:current) { "this" }
    page = build(:page)
    allow(page).to receive(:name).with("this") { "Here Titled" }
    allow(page).to receive(:icon) { "image_thingie.jpg" }
    allow(page).to receive(:id) { 43123 }
    collected_page = CollectedPage.new(page: page)
    assign(:page, page)
    assign(:collection, Collection.new)
    assign(:collected_page, collected_page)
  end

  context "with a new user" do
    before do
      user = instance_double("User", collections: [])
      assign(:bad_collection_ids, [])
      allow(view).to receive(:current_user) { user }
      render
    end

    it { expect(rendered).to match /image_thingie.jpg/ }
    it { expect(rendered).to match /Here Titled/ }
    it { expect(rendered).to match(/#{I18n.t(:collect_no_existing_collections)}/) }
    it { expect(rendered).to have_selector("form#new_collection") }
  end

  context "with a user who has collections already" do
    before do
      collection_1 = create(:collection, updated_at: 1.hour.ago,
        name: "Collection One", id: 1)
      collection_2 = create(:collection, updated_at: 1.minute.ago,
        name: "Collection Two", id: 2)
      collection_bad = create(:collection, updated_at: 2.hours.ago,
        name: "Collection Bad", id: 3)
      user_collections = [collection_1, collection_2, collection_bad]
      user = instance_double("User", collections: user_collections)
      assign(:bad_collection_ids, [collection_bad.id])
      allow(view).to receive(:current_user) { user }
      render
    end

    it "shows all of the available collections" do
      expect(rendered).to match /Collection One/
      expect(rendered).to match /Collection Two/
      expect(rendered).to match /Collection Bad/
    end

    it "shows the newest collection first" do
      expect(rendered).to match /Collection Two.*Collection One/m
    end

    it "disables the bad collection option" do
      expect(rendered).to have_selector(
        "input#collected_page_collection_id_3[disabled]")
    end
  end
end
