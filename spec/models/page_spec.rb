require 'rails_helper'

RSpec.describe Page do
  before(:all) do
    Section.brief_summary
  end

  describe "#score_richness" do
    let(:page) { create(:page) }
    it "should use the RichnessScore class" do
      expect(RichnessScore).to receive(:calculate).with(page) { :done }
      page.score_richness
    end
  end

  context "with many common names" do
    let!(:our_page) { create(:page) }
    let!(:name1) { create(:vernacular, node: our_page.native_node) }
    let!(:pref_name) { create(:vernacular, node: our_page.native_node,
      is_preferred: true) }
    let!(:name2) { create(:vernacular, node: our_page.native_node) }
    let!(:lang) { another_language }
    let!(:lang_name) { create(:vernacular, node: our_page.native_node,
      language: lang, is_preferred: true) }

    it "selects the preferred vernacular" do
      expect(our_page.name).to eq(pref_name.string)
    end

    it "has access to all vernaculars" do
      expect(our_page.vernaculars).to include(name1)
      expect(our_page.vernaculars).to include(name2)
      expect(our_page.vernaculars).to include(pref_name)
      expect(our_page.vernaculars).to include(lang_name)
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
        expect(our_page.name).to eq(lang_name.string)
      end
    end
  end

  context "with many scientific names" do
    let!(:our_page) { create(:page) }
    let!(:name1) { create(:scientific_name, node: our_page.native_node) }
    let!(:pref_name) do
      create(:preferred_scientific_name, node: our_page.native_node)
    end
    let!(:name2) { create(:scientific_name, node: our_page.native_node) }

    it "selects the preferred scientific name" do
      expect(our_page.scientific_name).to eq(our_page.native_node.canonical_form)
    end

    it "has access to all scientific names" do
      expect(our_page.scientific_names).to include(name1)
      expect(our_page.scientific_names).to include(name2)
      expect(our_page.scientific_names).to include(pref_name)
    end
  end

  context "with a brief summary and another article" do
    let!(:our_page) { create(:page) }
    let!(:summary) do
       article = create(:article)
       ContentSection.create(content: article, section: Section.brief_summary)
       PageContent.create(content: article, page: our_page, source_page: our_page)
       article
    end
    let!(:other_article) do
       article = create(:article)
       PageContent.create(content: article, page: our_page, source_page: our_page)
       article
    end

    it "chooses the summary for the overview" do
      expect(our_page.article).to eq(summary)
    end

    it "has access to both articles" do
      expect(our_page.articles).to include(summary)
      expect(our_page.articles).to include(other_article)
    end

  end

  context "with simple traits" do
    let(:our_page) { create(:page) }
    let(:predicate1) { { uri: "http://a/pred.1", name: "First predicate" } }
    let(:predicate2) { { uri: "http://a/pred.2", name: "Second predicate" } }
    let(:units) { { uri: "http://a/unit", name: "Units URI" } }
    let(:term) { { uri: "http://a/term", name: "Term 1 URI" } }
    let(:trait1) do
      { predicate: predicate2,
        resource_pk: "4003",
        object_term: term,
        metadata: nil }
    end
    let(:trait2) do
      { predicate: predicate1,
        resource_pk: "745",
        source: "Source One",
        units: units,
        measurement: "10.428",
        metadata: nil }
    end
    # This is a "fake" response from TraitBank (which normally needs neo4j)
    let(:traits_out_of_order) { [ trait1, trait2 ] }
    let(:glossary) { { predicate1[:uri] => predicate1, predicate2[:uri] => predicate2 }}

    before do
      allow(TraitBank).to receive(:by_page) { traits_out_of_order }
    end

    it "#traits orders traits" do
      traits = our_page.traits
      expect(traits.first[:predicate][:uri]).to eq(predicate1[:uri])
    end

    it "#glosasry builds a glossary" do
      allow(TraitBank).to receive(:page_glossary).with(our_page.id) { true }
      our_page.glossary
    end

    it "#grouped_traits groups traits" do
      expect(our_page.grouped_traits.keys.sort).
        to eq([predicate1[:uri], predicate2[:uri]].sort)
    end

    it "#predicates orders predicates" do
      allow(TraitBank).to receive(:page_glossary) { glossary }
      expect(our_page.predicates).
        to eq([predicate1, predicate2].sort { |a,b| a[:name] <=> b[:name] }.map { |p| p[:uri] })
    end

    it "#is_it_extinct false" do
      expect(our_page.is_it_extinct?).not_to be_truthy
    end

    it "#is_it_marine false" do
      expect(our_page.is_it_marine?).not_to be_truthy
    end

    it "#habitats nil" do
      expect(our_page.habitats).to be_nil
    end

    it "#iucn_status_key nil" do
      expect(our_page.iucn_status_key).to be_nil
    end
  end

  # IF ExtinctionStatusResource and PaleoDB records are available and their values are not the same, consider the ExtinctionStatusResource record
  # IF ExtinctionStatusResource is available and PaleoDB is not, consider the ExtinctionStatusResource record
  # IF PaleoDB is available and ExtinctionStatusResource is not, consider the PaleoDB record
  # IF the record selected for consideration has value http://eol.org/schema/terms/extinct, display the record on the cover.
  # IF the record selected for consideration has any other value, display no /ExtinctionStatus records on the cover
  # IF neither ExtinctionStatusResource nor PaleoDB records are available AND
  # IF records from any other resource are available, AND have value = http://eol.org/schema/terms/extinct, display one such record on the cover. If multiple such records exist, one can be selected arbitrarily by any method.

  context "#displayed_extinction_trait" do
    let!(:paleo_db) do
      Resource.where(name: "The Paleobiology Database").first_or_create do |r|
        r.name = "The Paleobiology Database"
        r.partner = create(:partner)
      end
    end
    let(:paleo_extinct) do
      fake_fact(Eol::Uris.extinction, Eol::Uris.extinct, resource_id: paleo_db.id)
    end
    let(:paleo_extant) do
      fake_fact(Eol::Uris.extinction, "http://alive.com", resource_id: paleo_db.id)
    end

    let!(:ex_stat) do
      Resource.where(name: "Extinction Status").first_or_create do |r|
        r.name = "Extinction Status"
        r.partner = create(:partner)
      end
    end
    let(:ex_stat_extinct) do
      fake_fact(Eol::Uris.extinction, Eol::Uris.extinct, resource_id: ex_stat.id)
    end
    let(:ex_stat_extant) do
      fake_fact(Eol::Uris.extinction, "http://alive.com", resource_id: ex_stat.id)
    end

    let(:other_extinct) do
      fake_fact(Eol::Uris.extinction, Eol::Uris.extinct)
    end
    let(:other_extant) do
      fake_fact(Eol::Uris.extinction, "http://alive.com")
    end

    let!(:our_page) { create(:page) }

    context "when extinct from both resources" do
      let(:traits) { [ex_stat_extinct, paleo_extinct, other_extinct] }

      it "returns the PaleoDB record" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to eq(paleo_extinct)
      end
    end

    context "when extinct from PaleoDB and extant from ExStatRes" do
      let(:traits) { [ex_stat_extant, paleo_extinct, other_extinct] }

      it "returns nil" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to be_nil
      end
    end

    context "when extant from PaleoDB and extinct from ExStatRes" do
      let(:traits) { [ex_stat_extinct, paleo_extant, other_extinct] }

      it "returns ExStatRes record" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to eq(ex_stat_extinct)
      end
    end

    context "when only PaleoDB extinct" do
      let(:traits) { [paleo_extinct, other_extinct] }

      it "returns PaleoDB record" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to eq(paleo_extinct)
      end
    end

    context "when only ExStatRes extinct" do
      let(:traits) { [ex_stat_extinct, other_extinct] }

      it "returns ExStatRes record" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to eq(ex_stat_extinct)
      end
    end

    context "when only extinct in other resource" do
      let(:traits) { [other_extinct] }

      it "returns that other record" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to eq(other_extinct)
      end
    end

    context "when only extant in other resource" do
      let(:traits) { [other_extant] }

      it "returns nil" do
        allow(TraitBank).to receive(:by_page) { traits }
        our_page.traits
        expect(our_page.displayed_extinction_trait).to be_nil
      end
    end
  end

  context "with faked traits" do
    let!(:iucn) do
      Resource.where(name: "IUCN Structured Data").first_or_create do |r|
        r.name = "IUCN Structured Data"
        r.partner = create(:partner)
      end
    end

    let(:our_page) { create(:page) }
    let(:traits) { [
      extinct_trait,
      dd_iucn_trait(iucn),
      marine_trait,
      fake_literal_trait(Eol::Uris.geographics.first, "atlantis"),
      fake_fact(Eol::Uris.geographics.second, "http://earth.com", name: "Earth")
    ] }

    before do
      allow(TraitBank).to receive(:by_page) { traits }
      # These specs only work when traits are pre-loaded:
      our_page.traits
    end

    it "#is_it_extinct true" do
      expect(our_page.is_it_extinct?).to be_truthy
    end

    it "#is_it_marine true" do
      expect(our_page.is_it_marine?).to be_truthy
    end

    it "#iucn_status_key dd" do
      expect(our_page.iucn_status_key.to_s).to eq("dd")
    end

    # NOTE: we test two of them for TWO resons: one, to test that both literal
    # values and term values are read, and two: so we see that the values are
    # joined with the ", " that we expect.
    it "#habitats atlantis, Earth" do
      expect(our_page.habitats.split(", ").sort).
        to eq(["atlantis", "Earth"].sort)
    end
  end
end
