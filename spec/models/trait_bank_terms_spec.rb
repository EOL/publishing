require "rails_helper"

RSpec.describe TraitBank::Terms do
  let(:conn) { instance_double(Neography::Rest) }

  before do
    allow(TraitBank).to receive(:query) { }
    allow(Rails.configuration).to receive(:data_glossary_page_size)
  end

  describe ".count" do
    it "caches the value" do
      expect(Rails.cache).to receive(:fetch) { :foo }
      expect(TraitBank::Terms.count).to eq(:foo)
    end

    it "queries TraitBank" do
      expect(TraitBank::Terms).to receive(:query).
        with( /count\(distinct\(term\.uri\)\)/i ) {
        { "data" => [[:foo]] }
      }
      expect(TraitBank::Terms.count).to eq(:foo)
    end
  end

  describe ".full_glossary" do
    it "caches the value" do
      expect(Rails.cache).to receive(:fetch) { :this }
      expect(TraitBank::Terms.full_glossary).to eq(:this)
    end

    it "queries TraitBank" do
      expect(TraitBank::Terms).to receive(:query).
        with( /is_hidden_from_glossary: false.*distinct\(term\).*order by lower\(term.name\), lower\(term.uri\)/i ) {
        { "data" => [["data" => { "foo" => "bar" }]] }
      }
      expect(TraitBank::Terms.full_glossary).to eq([{ foo: "bar" }])
    end
  end

  describe ".sub_glossary" do
    it "caches the value" do
      expect(Rails.cache).to receive(:fetch) { :this }
      expect(TraitBank::Terms.sub_glossary(:which)).to eq(:this)
    end

    it "queries TraitBank" do
      expect(TraitBank::Terms).to receive(:query).
        with( /is_hidden_from_glossary: false.*[:which].*distinct\(term\).*lower\(term.name\), lower\(term.uri\)/i ) {
        { "data" => [["data" => { "foo" => "bar" }]] }
      }
      expect(TraitBank::Terms.sub_glossary(:which)).to eq([{ foo: "bar" }])
    end

    it "can count" do
      expect(TraitBank::Terms).to receive(:query).
        with( /COUNT\(DISTINCT\(term.uri\)\)/i ) {
        { "data" => [[:this]] }
      }
      expect(TraitBank::Terms.sub_glossary(:which, 1, 1, true)).to eq(:this)
    end
  end
end
