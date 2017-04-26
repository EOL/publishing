require 'rails_helper'

RSpec.describe RichnessScore do
  describe "#calculate" do
    let(:medium) { instance_double("PageContent", content_type: "medium") }
    let(:article) { instance_double("PageContent", content_type: "article") }
    let(:link) { instance_double("PageContent", content_type: "link") }

    before(:each) do
      allow(Section).to receive(:count) { 10 }
      allow(TraitBank).to receive(:predicate_count) { 100 }
    end

    context("with a rich-ish page") do

      let(:page) do
        instance_double("Page", media_count: 2, map?: true, sections: [1,2,3],
          glossary: [1,2,3,4], literature_and_references_count: 3,
          page_contents: [medium, article, link])
      end

      it "should score 3086 as configured" do
        expect(RichnessScore.calculate(page)).to eq 3086
      end
    end

    context("with an empty page") do
      let(:page) do
        instance_double("Page", media_count: 0, map?: false, sections: [],
          glossary: [], literature_and_references_count: 0,
          page_contents: [])
      end

      it "should check all of the counts" do
        expect(page).to receive(:media_count) { 0 }
        expect(page).to receive(:map?) { false }
        expect(page).to receive(:sections) { [] }
        expect(page).to receive(:glossary) { [] }
        expect(page).to receive(:literature_and_references_count) { 0 }
        expect(page).to receive(:page_contents) { [] }
        RichnessScore.calculate(page)
      end

      it "should explain the score" do
        expect(RichnessScore.explain(page)).to eq("Media: 0 -> 0 * 0.34 = 0.0\n"\
          "Media Diversity: 0 -> 0 * 0.03 = 0\n"\
          "Map: false -> 0.1 = 0\n"\
          "Section Diversity: 0 / 10 -> 0.0 * 0.25 = 0.0\n"\
          "Data Diversity: 0 / 100 -> 0.0 * 0.25 = 0.0\n"\
          "References: 0 -> 0 * 0.03 = 0.0\n"\
          "TOTAL: 0")
      end

      it "scores 0" do
        expect(RichnessScore.calculate(page)).to eq 0.0
      end
    end
  end
end
