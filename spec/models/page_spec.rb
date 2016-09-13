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
    let!(:pref_name) { create(:vernacular, node: our_page.native_node, is_preferred: true) }
    let!(:name2) { create(:vernacular, node: our_page.native_node) }

    it "selects the preferred vernacular" do
      expect(our_page.name).to eq(pref_name.string)
    end

    it "has access to all vernaculars" do
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
      expect(our_page.top_articles.first).to eq(summary)
    end

    it "has access to both articles" do
      expect(our_page.articles).to include(summary)
      expect(our_page.articles).to include(other_article)
    end

  end

  context "with traits" do
    let(:our_page) { create(:page) }
    let(:predicate1) { create(:uri, name: "First predicate" )}
    let(:predicate2) { create(:uri, name: "Second predicate" )}
    let(:units) { create(:uri, name: "Units URI" )}
    let(:term) { create(:uri, name: "Term 1 URI" )}
    # This is a "fake" response from TraitBank (which normally needs neo4j)
    let(:traits_out_of_order) do
      [
        { predicate: predicate2.uri,
          resource_pk: "4003",
          term: term.uri,
          metadata: nil },
        { predicate: predicate1.uri,
            resource_pk: "745",
            source: "Source One",
            units: units.uri,
            measurement: "10.428",
            metadata: nil }
      ]
    end

    it "orders traits" do
      allow(TraitBank).to receive(:by_page) { traits_out_of_order }
      traits = our_page.traits
      expect(traits.first[:predicate]).to eq(predicate1.uri)
    end

    it "builds a glossary" do
      allow(TraitBank).to receive(:by_page) { traits_out_of_order }
      expect(our_page.glossary.keys).to include(predicate1.uri)
      expect(our_page.glossary.keys).to include(predicate2.uri)
      expect(our_page.glossary.keys).to include(units.uri)
      expect(our_page.glossary.keys).to include(term.uri)
    end
  end
end
