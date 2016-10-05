require 'rails_helper'

RSpec.describe CollectedPage do
  let(:page) { create(:page) }

  context "with NO overrides" do
    subject { CollectedPage.new(page: page) }

    it "#item returns the page, to duck-type with CollectionAssociation" do
      expect(subject.item).to eq(page)
    end

    it "#name uses the page" do
      expect(page).to receive(:name) { "thisName" }
      expect(subject.name).to eq("thisName")
    end

    it "#scientific_name_string uses the page" do
      expect(page).to receive(:scientific_name) { "thisSciName" }
      expect(subject.scientific_name_string).to eq("thisSciName")
    end

    context "with a top_image on the page" do
      let(:image) do
        instance_double("Medium", medium_icon_url: "thisIconMed",
          small_icon_url: "thisIconSm")
      end

      before do
        allow(page).to receive(:top_image) { image }
      end

      it "#medium_icon_url uses the page's top_image" do
        expect(subject.medium_icon_url).to eq("thisIconMed")
      end

      it "#icon uses the page's top_image's medium_icon_url" do
        expect(subject.icon).to eq("thisIconMed")
      end

      it "#small_icon_url uses the page's top_image" do
        expect(subject.small_icon_url).to eq("thisIconSm")
      end
    end
  end

  context "with overrides" do
    let(:vernacular) { create(:vernacular) }
    let(:scientific_name) { create(:scientific_name) }
    let(:medium) { create(:medium) }

    subject do
      CollectedPage.new(page: page, media: [medium])
    end

    it "#name uses the override" do
      expect(subject.name).to eq(page.name)
    end

    it "#scientific_name_string uses the override's canonical_form" do
      expect(subject.scientific_name_string).to eq(page.scientific_name)
    end

    it "#medium_icon_url uses the override" do
      expect(subject.medium_icon_url).to eq(medium.medium_icon_url)
    end

    it "#icon uses the the override's medium_icon_url" do
      expect(subject.icon).to eq(medium.medium_icon_url)
    end

    it "#small_icon_url uses the the override" do
      expect(subject.small_icon_url).to eq(medium.small_icon_url)
    end
  end
end
