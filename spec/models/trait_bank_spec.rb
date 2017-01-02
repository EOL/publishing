require 'rails_helper'

RSpec.describe TraitBank do
  
 
  
  before :all do
    predicate = {
        uri: "http://eol.org/schema/terms/FattyAcidCompositionOfMilk",
        name: "fatty acid composition of milk",
        definition: "",
        comment: "",
        attribution: "",
        is_hidden_from_overview: false,
        is_hidden_from_glossary: false
      }
    pred = TraitBank.create_term(predicate.symbolize_keys)
    page = Page.create
    page_node = TraitBank.create_page(page.id)
    trait = TraitBank.create_trait(page: page_node,
                   supplier: 1,
                   resource_pk: "m_00008532",
                   scientific_name: "sci_name",
                   predicate: pred,
                   source: t_data["source"],#??
                   measurement: 10,
                   statistical_method: "stat_method",
                   lifestage: "baby",
                   sex: "male",
                   literal: "literal",
                   object_page_id: 2,)
  end
            
  it "responds to :connection" do
    TraitBank.should respond_to(:connection)
  end
  it "responds to :ping" do
    TraitBank.should respond_to(:ping)
  end
  it "responds to :connect" do
    TraitBank.should respond_to(:connect)
  end
  it "responds to :setup" do
    TraitBank.should respond_to(:setup)
  end
  it "responds to :create_indexes" do
    TraitBank.should respond_to(:create_indexes)
  end 
  it "responds to :create_constraints" do
    TraitBank.should respond_to(:create_constraints)
  end 
  it "responds to :nuclear_option!" do
    TraitBank.should respond_to(:nuclear_option!)
  end
  
  
end