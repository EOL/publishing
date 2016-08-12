require 'rails_helper'

RSpec.describe Page do
  context "with many common names" do
    let!(:our_page) { create(:page) }
    let!(:name1) { create(:vernacular, node: our_page.native_node) }
    let!(:pref_name) { create(:vernacular, node: our_page.native_node, is_preferred: true) }
    let!(:name2) { create(:vernacular, node: our_page.native_node) }

    it "should select the preferred vernacular" do
      expect(our_page.common_name).to eq(pref_name)
    end

    it "should have access to all names" do
      expect(our_page.vernaculars).to include(name1)
      expect(our_page.vernaculars).to include(name2)
      expect(our_page.vernaculars).to include(pref_name)
    end
  end

end
