require 'rails_helper'

RSpec.describe Rank do
  describe ".all_species_ids" do
    it "caches the value" do
      expect(Rails.cache).to receive(:fetch) { :foo }
      expect(Rank.all_species_ids).to eq(:foo)
    end

    # NOTE: we can't really check that treat_as is called with the right args,
    # and it's not really worth implementing by mocking models in the DB. (Not
    # here; it might be for harvesting.)
    it "looks up rank ids treated as speces" do
      expect(Rank).to receive(:treat_as) { { } }
      expect(Rank).to receive_message_chain(:where, :pluck) { :this }
      expect(Rank.all_species_ids).to eq(:this)
    end
  end

  describe ".all_species_ids" do
    it "caches the value" do
      expect(Rails.cache).to receive(:fetch) { :foo }
      expect(Rank.all_species_ids).to eq(:foo)
    end

    # See previous NOTE.
    it "looks for the expected ranks" do
      expect(Rank).to receive(:treat_as) { { } }
      expect(Rank).to receive_message_chain(:where, :pluck) { :this }
      expect(Rank.all_species_ids).to eq(:this)
    end
  end

  describe ".guess_treat_as" do
    it "should add r_ to the name if we know about it" do
      expect(Rank.guess_treat_as("species")).to eq(:r_species)
    end

    it "should treat infradivision as infraphylum" do
      expect(Rank.guess_treat_as("infradivision")).to eq(:r_infraphylum)
    end

    it "should treat superdivision as superphylum" do
      expect(Rank.guess_treat_as("superdivision")).to eq(:r_superphylum)
    end

    it "should treat subdivision as subphylum" do
      expect(Rank.guess_treat_as("subdivision")).to eq(:r_subphylum)
    end

    it "should treat division as phylum" do
      expect(Rank.guess_treat_as("division")).to eq(:r_phylum)
    end

    it "should treat variety as infraspecies" do
      expect(Rank.guess_treat_as("variety")).to eq(:r_infraspecies)
    end

    it "should treat k as kingdom" do
      expect(Rank.guess_treat_as("k")).to eq(:r_kingdom)
    end

    it "should treat sp as species" do
      expect(Rank.guess_treat_as("sp")).to eq(:r_species)
    end

    it "should treat g as genus" do
      expect(Rank.guess_treat_as("g")).to eq(:r_genus)
    end

    it "should treat c as class" do
      expect(Rank.guess_treat_as("c")).to eq(:r_class)
    end

    it "should treat clas as class" do
      expect(Rank.guess_treat_as("clas")).to eq(:r_class)
    end

    it "should treat subc as subclass" do
      expect(Rank.guess_treat_as("subc")).to eq(:r_subclass)
    end

    # NOTE: it could handle a lot more, but if it does these, it's doing well.
  end
end
