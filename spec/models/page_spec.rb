require 'rails_helper'

RSpec.describe Page do
  context "with many common names" do
    let!(:our_page) { create(:page) }
    let!(:name1) { create(:vernacular, node: our_page.native_node) }
    let!(:pref_name) { create(:vernacular, node: our_page.native_node, is_preferred: true) }
    let!(:name2) { create(:vernacular, node: our_page.native_node) }

    it "should select the preferred vernacular" do
      expect(our_page.name).to eq(pref_name)
    end

    it "should have access to all vernaculars" do
      expect(our_page.vernaculars).to include(name1)
      expect(our_page.vernaculars).to include(name2)
      expect(our_page.vernaculars).to include(pref_name)
    end
  end

  context "with many scientific names" do
    let!(:our_page) { create(:page) }
    let!(:name1) { create(:scientific_name, node: our_page.native_node) }
    let!(:pref_name) do
      create(:preferred_scientific_name, node: our_page.native_node)
    end
    let!(:name2) { create(:scientific_name, node: our_page.native_node) }

    it "should select the preferred scientific name" do
      expect(our_page.scientific_name).to eq(pref_name)
    end

    it "should have access to all scientific names" do
      expect(our_page.scientific_names).to include(name1)
      expect(our_page.scientific_names).to include(name2)
      expect(our_page.scientific_names).to include(pref_name)
    end
  end
end
