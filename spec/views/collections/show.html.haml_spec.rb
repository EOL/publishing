require "rails_helper"

RSpec.describe "collections/show" do

  let(:collection1) { create(:medium) }
  let(:collection2) { create(:medium) }
  let(:page) { create(:page) }
  let(:collected_page) { create(:collected_page, page: page) }

  before do
    allow(view).to receive(:policy).and_return(double("some policy", update?: false))
    allow(view).to receive(:is_admin?) { false }
    allow(page).to receive(:icon) { "some_icon" }
    allow(page).to receive(:name) { "funName" }
  end

  context "normal view" do
    context "(with robust collection)" do
      before do
        collection = instance_double("Collection",
          collections: [collection1, collection2],
          id: 1,
          name: "Col Name 1",
          description: "Col Description Here",
          gallery?: false)
        @collection = collection
        @pages = fake_pagination([collected_page])
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
          expect(rendered).to have_selector("#collected_pages_search input#q")
        end

        it 'has collected page div (to be replaced)' do
          render
          expect(rendered).to have_selector("#collected_pages")
        end
      end
    end
  end

  context "gallery view" do
    context "(with robust collection)" do
      before do
        collection = instance_double("Collection",
          collections: [collection1, collection2],
          id: 2,
          name: "Col Name 1",
          description: "Col Description Here",
          gallery?: true)
        @collection = collection
        @pages = fake_pagination([collected_page])
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
      end

      it "shows the icons of all collected associations" do
        render
        expect(rendered).to have_selector("img[src='#{collection1.icon}']")
        expect(rendered).to have_selector("img[src='#{collection2.icon}']")
      end
    end
  end

  context "(with empty collection)" do
    before do
      collection = instance_double("Collection", collections: [],
        name: "Col Name Again", description: nil, id: 3)
      assign(:collection, collection)
      assign(:pages, fake_pagination([]))
      render
    end

    it { expect(rendered).to have_content("Col Name Again") }
    it { expect(rendered).to match(/#{I18n.t(:collection_pages_empty).gsub("\"", "&quot;")}/) }
    it { expect(rendered).to match(/#{I18n.t(:collection_associations_empty).gsub("\"", "&quot;")}/) }
    it { expect(rendered).not_to have_selector("a", text: "edit") }

    context "when owned by the user" do
      it "shows an edit button" do
        # Required to render one of the links:
        allow(view).to receive(:params).
          and_return({ action: "show", controller: "collections", id: 3 })
        expect(view).to receive(:policy).
          and_return(double("some policy", update?: true))
        render
        expect(rendered).to have_selector("a", text: "edit")
      end
    end
  end

end
