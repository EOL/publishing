require 'rails_helper'

RSpec.describe TermsController do
  let(:trait) do
    { :resource_pk=>"d7cf04b725e0c2f140489261ef365952", :source=>"Procyonidae",
      :metadata=>nil, :resource_id=>17, :predicate=>{:section_ids=>"",
      :name=>"extinction status", :attribution=>"",
      :is_hidden_from_glossary=>false, :comment=>"", :definition=>"Indicates
      whether a taxon is extant (living today) or extinct.",
      :is_hidden_from_overview=>false,
      :uri=>"http://eol.org/schema/terms/ExtinctionStatus"},
      :object_term=>{:section_ids=>"", :name=>"extant",
      :attribution=>"http://en.wikipedia.org/wiki/Extant_taxon",
      :is_hidden_from_glossary=>false, :definition=>"This taxon is still in
      existence, as opposed to extinct.", :comment=>"",
      :is_hidden_from_overview=>false,
      :uri=>"http://eol.org/schema/terms/extant"},
      :id=>"trait:17:d7cf04b725e0c2f140489261ef365952"
    }
  end
  let(:resource) { create(:resource) }
  let(:page_measured) { create(:page) }
  let(:page_term) { create(:page) }
  let(:page_literal) { create(:page) }
  let(:units) { { uri: "http://units.com/unit/inch", name: "inch",
    definition: "inching" } }
  let(:term) { { uri: "http://terms.com/size/big", name: "big",
    definition: "large" } }
  let(:glossary) { { units[:uri] => units, term[:uri] => term } }
  let(:grouped_traits) do
    [ { page_id: page_measured.id, measurement: "657", units: units[:uri],
        resource_id: resource.id },
      { page_id: page_term.id, term: term[:uri], resource_id: resource.id },
      { page_id: page_literal.id, literal: "literal trait value",
        resource_id: resource.id }
    ]
  end
  let(:pages) { [page_measured, page_term, page_literal] }

  before do
    allow(TraitBank).to receive(:by_predicate) { grouped_traits }
    allow(TraitBank).to receive(:glossary) { glossary }
    allow(TraitBank).to receive(:resources) { [resource] }
  end

  describe '#show' do
    before do
      get :show, uri: trait[:predicate][:uri]
    end

    it { expect(assigns(:term)[:uri]).to eq(trait[:predicate][:uri]) }
    it { expect(assigns(:glossary)).to eq(glossary) }
    it { expect(assigns(:resources)).to eq([resource]) }
    it { expect(assigns(:grouped_traits)).to eq(grouped_traits) }

    it "assigns pages" do
      pages.each do |page|
        expect(assigns(:pages).values).to include(page)
      end
    end
  end
end
