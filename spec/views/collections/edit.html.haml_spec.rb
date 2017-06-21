require "rails_helper"

RSpec.describe "collections/edit" do
  let(:page) { create(:page) }
  let(:collected_page) { create(:collected_page, page: page) }

  let(:collection) { create(:collection) }
  let(:pages) { [collected_page] }

  before do
    assign(:collection, collection)
    assign(:pages, pages)
    allow(view).to receive(:policy).and_return(double("some policy", update?: false))
  end

  context "with simple pages" do
    before do
      render
    end

    it { expect(rendered).to have_selector("form#edit_collection_#{collection.id}") }
    it { expect(rendered).to have_selector("input#collection_name") }
    it { expect(rendered).to have_selector("textarea#collection_description") }
    it { expect(rendered).to have_selector("input#collection_collection_type_normal") }
    it { expect(rendered).to have_selector("input#collection_collection_type_gallery") }
    it { expect(rendered).to match(collected_page.name) }
    it { expect(rendered).to match(collected_page.scientific_name_string) }
    it { expect(rendered).to match(I18n.t(:collected_pages_title)) }
  end
end
