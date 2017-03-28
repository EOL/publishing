require 'rails_helper'

RSpec.describe Page do
  before(:all) do
    # TODO: this is problematic: class variables seem to become invalid between
    # specs (if they are first called from within them) because of the
    # first_or_create stuff. We'll have to have some kind of bootstrap to load
    # into the DB... or add some code to clear class variables between specs
    # (which sounds expensive).
    Section.brief_summary
  end

  context "with many common names" do
    let!(:our_page) { create(:page) }
    let!(:name1) { create(:vernacular, node: our_page.native_node) }
    let!(:pref_name) { create(:vernacular, node: our_page.native_node,
      is_preferred: true) }
    let!(:name2) { create(:vernacular, node: our_page.native_node) }
    let!(:lang) { create(:language, group: "de") }
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

  context "with traits" do
    let(:our_page) { create(:page) }
    let(:predicate1) { { uri: "http://a/pred.1", name: "First predicate" } }
    let(:predicate2) { { uri: "http://a/pred.2", name: "Second predicate" } }
    let(:units) { { uri: "http://a/unit", name: "Units URI" } }
    let(:term) { { uri: "http://a/term", name: "Term 1 URI" } }
    # This is a "fake" response from TraitBank (which normally needs neo4j)
    let(:traits_out_of_order) do
      [
        { predicate: predicate2,
          resource_pk: "4003",
          object_term: term,
          metadata: nil },
        { predicate: predicate1,
          resource_pk: "745",
          source: "Source One",
          units: units,
          measurement: "10.428",
          metadata: nil }
      ]
    end

    before do
      allow(TraitBank).to receive(:by_page) { traits_out_of_order }
    end

    it "#traits orders traits" do
      traits = our_page.traits
      expect(traits.first[:predicate][:uri]).to eq(predicate1[:uri])
    end

    it "#glosasry builds a glossary" do
      allow(TraitBank).to receive(:by_page) { traits_out_of_order }
      expect(our_page.glossary.keys).to include(predicate1[:uri])
      expect(our_page.glossary.keys).to include(predicate2[:uri])
      expect(our_page.glossary.keys).to include(units[:uri])
      expect(our_page.glossary.keys).to include(term[:uri])
    end

    it "#grouped_traits groups traits" do
      expect(our_page.grouped_traits.keys.sort).
        to eq([predicate1[:uri], predicate2[:uri]].sort)
    end

    it "#predicates orders predicates" do
      expect(our_page.predicates).
        to eq([predicate1, predicate2].sort { |a,b| a[:name] <=> b[:name] }.map { |p| p[:uri] })
    end
  end
end
