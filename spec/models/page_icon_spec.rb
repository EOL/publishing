require 'rails_helper'

RSpec.describe PageIcon do
  let(:page) { create(:empty_page) }
  let(:image) { create(:image) }
  let(:user) { create(:user) }
  let(:page_icon) { PageIcon.new(page: page, medium: image, user: user) }

  describe "#page_content" do
    let!(:page_content) { PageContent.create(page: page, content: image,
      source_page_id: page.id) }

    it "finds the page content affected" do
      expect(page_icon.page_content).to eq(page_content)
    end
  end

  describe "#bump_icon" do
    it "moves the content to the top" do
      content = instance_double("PageContent")
      expect(content).to receive(:move_to_top) { }
      expect(page_icon).to receive(:page_content).at_least(1).times { content }
      page_icon.save
    end
  end
end
