require 'rails_helper'

RSpec.describe Node do
  # context "no vernaculars" do
    # let(:node) { create(:node) }
    # it "has scientific name" do
      # expect(node.name).to eq(node.scientific_name)
    # end
  # end

  context "with vernaculars" do
    let!(:node) { create(:node) }
    let!(:ver) { create(:vernacular, node: node, is_preferred: true) }
    let!(:lang) { another_language }
    let!(:lang_name) { create(:vernacular, node: node, language: lang,
      is_preferred: true) }

    it "uses preloaded preferred vernaculars" do
      expect(node.name).to eq(ver.string)
    end

    context "in another language" do
      before do
        @old_locale = I18n.locale
        I18n.locale = :de
      end

      after do
        I18n.locale = @old_locale
      end

      it "gets the right vernacular for language" do
        expect(node.name).to eq(lang_name.string)
      end
    end
  end
end
