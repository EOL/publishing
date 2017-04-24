require "rails_helper"

RSpec.describe TraitBank do
  let(:conn) { instance_double(Neography::Rest) }

  describe ".connection" do
    after do
      TraitBank.class_eval { remove_instance_variable(:@connection) }
    end

    it "uses Neography::Rest exactly once, resuses connection" do
      expect(Neography::Rest).to receive(:new).exactly(1).times { :connected }
      expect(TraitBank.connection).to eq(:connected)
      expect(TraitBank.connection).to eq(:connected)
    end

    it "connects with EOL_TRAITBANK_URL from ENV" do
      expect(ENV).to receive(:[]).with("EOL_TRAITBANK_URL") { :this_val }
      expect(Neography::Rest).to receive(:new).with(:this_val)
      TraitBank.connection
    end
  end

  # NOTE: I don't actually care how the ping itself is implemented. I just care
  # about how it detects the expected error.
  describe ".ping" do
    it "returns false if timed out" do
      allow(conn).to receive(:list_indexes).and_raise(Excon::Error::Socket.new)
      allow(TraitBank).to receive(:connection) { conn }
      expect(TraitBank.ping).to eq(false)
    end
  end

  describe "query" do
    it "passes the query along to the connection" do
      expect(conn).to receive(:execute_query).with(:this) { :results }
      allow(TraitBank).to receive(:connection) { conn }
      expect(TraitBank.query(:this)).to eq(:results)
    end

    it "detects timeouts and sleeps before retrying" do
      expect(conn).to receive(:execute_query).exactly(2).times.and_raise(Excon::Error::Timeout.new)
      expect(TraitBank).to receive(:sleep).with(1)
      allow(TraitBank).to receive(:connection) { conn }
      expect { TraitBank.query(:this) }.to raise_error(Excon::Error::Timeout)
    end
  end

  describe ".quote" do
    it "returns 100 if it's 100" do
      val = 100
      # NOTE: no need to check gsub here; would fail on an integer anyway!
      expect(TraitBank.quote(val)).to eq(val)
    end

    it "returns '100' if it's '100'" do
      val = "100"
      expect(val).not_to receive(:gsub)
      expect(TraitBank.quote(val)).to eq(val)
    end

    it "returns the same if it's '-34,345.99'" do
      val = "-34,345.99"
      expect(val).not_to receive(:gsub)
      expect(TraitBank.quote(val)).to eq(val)
    end

    it "quotes" do
      val = "some string"
      expect(TraitBank.quote(val)).to eq("\"#{val}\"")
    end

    it "metaquotes" do
      val = "something with \"quotes\" in it"
      expect(TraitBank.quote(val)).to eq("\"something with \\\"quotes\\\" in it\"")
    end
  end

  describe ".setup" do
    it "calls .create_indexes and .create_constraints" do
      expect(TraitBank).to receive(:create_indexes)
      expect(TraitBank).to receive(:create_constraints)
      TraitBank.setup
    end
  end

  context "with stubbed queries" do
    before do
      allow(TraitBank).to receive(:query) { }
    end

    # NOTE: these may seem like relatively silly tests, but these Indexes are
    # really important.
    describe ".create_indexes" do
      it "creates page index" do
        expect(TraitBank).to receive(:query).with("CREATE INDEX ON :Page(page_id);")
        TraitBank.create_indexes
      end

      it "creates trait index" do
        expect(TraitBank).to receive(:query).with("CREATE INDEX ON :Trait(resource_pk);")
        TraitBank.create_indexes
      end

      it "creates term index" do
        expect(TraitBank).to receive(:query).with("CREATE INDEX ON :Term(uri);")
        TraitBank.create_indexes
      end

      it "creates resource index" do
        expect(TraitBank).to receive(:query).with("CREATE INDEX ON :Resource(resource_id);")
        TraitBank.create_indexes
      end
    end

    # NOTE: these are LESS important than indexes, so I'm not testing them; just
    # the case of the failure, since that IS important.
    describe ".create_constraints" do
      it "handles existing contraints" do
        allow(TraitBank).to receive(:query)
        expect(TraitBank).to receive(:query).and_raise(Neography::NeographyError.new("already exists"))
        expect { TraitBank.create_constraints }.not_to raise_error
      end

      it "fails on any other error" do
        # NOTE the typo. ;)
        allow(TraitBank).to receive(:query)
        expect(TraitBank).to receive(:query).and_raise(Neography::NeographyError.new("already exits"))
        expect { TraitBank.create_constraints }.to raise_error(Neography::NeographyError)
      end
    end
  end

  describe ".trait_count" do
    it "should return a count" do
      result = { "data" => [[123, 234], :not_this] }
      expect(TraitBank).to receive(:query).with(/RETURN count/) { result }
      expect(TraitBank.trait_count).to eq(123)
    end
  end

  describe ".glossary_count" do
    it "should return a count" do
      result = { "data" => [[234, 456], :not_this] }
      expect(TraitBank).to receive(:query).with(/RETURN count/) { result }
      expect(TraitBank.glossary_count).to eq(234)
    end
  end

  describe ".trait_exists?" do
    it "query with the QUOTED trait ID and return a result" do
      result = { "data" => [:this_result] }
      expect(TraitBank).to receive(:query).with(/\"trait\\\" ID/) { result }
      expect(TraitBank.trait_exists?("_", "trait\" ID")).to eq(:this_result)
    end

    it "query with the resource ID and return a result" do
      result = { "data" => [:this_result] }
      expect(TraitBank).to receive(:query).with(/res_id/) { result }
      expect(TraitBank.trait_exists?("res_id", "_")).to eq(:this_result)
    end
  end

  describe ".by_trait" do
    let(:full_id) { "nothing--The_resourceID--traitIDHere" }

    before do
      allow(TraitBank).to receive(:query) { }
      allow(TraitBank).to receive(:build_trait_array) { :result_set }
    end

    it "query with the QUOTED trait ID" do
      expect(TraitBank).to receive(:query).
        with(/:trait.*Trait.*resource_pk: \"traitIDHere\"/) { }
      TraitBank.by_trait(full_id)
    end

    it "query with the resource ID" do
      expect(TraitBank).to receive(:query).with(/resource:Resource { resource_id: The_resourceID }/) { }
      TraitBank.by_trait(full_id)
    end

    it "query with the predicate" do
      expect(TraitBank).to receive(:query).with(/:predicate.*Term/) { }
      TraitBank.by_trait(full_id)
    end

    it "query with the optional object term" do
      expect(TraitBank).to receive(:query).with(/OPTIONAL MATCH.*:object_term.*:Term/) { }
      TraitBank.by_trait(full_id)
    end

    it "query with the optional units term" do
      expect(TraitBank).to receive(:query).with(/OPTIONAL MATCH.*:units_term.*:Term/) { }
      TraitBank.by_trait(full_id)
    end

    it "calls .build_trait_array" do
      expect(TraitBank).to receive(:build_trait_array) { :results }
      expect(TraitBank.by_trait(full_id)).to eq(:results)
    end
  end

  describe ".by_page" do
    before do
      allow(TraitBank).to receive(:query) { }
      allow(TraitBank).to receive(:build_trait_array) { :result_set }
    end

    it "finds a page" do
      expect(TraitBank).to receive(:query).with(/page:Page.*page_id: 432/)
      TraitBank.by_page(432)
    end

    it "finds traits" do
      expect(TraitBank).to receive(:query).with(/:trait.*trait:Trait/)
      TraitBank.by_page(1)
    end

    it "finds the supplier resource" do
      expect(TraitBank).to receive(:query).with(/:supplier.*resource:Resource/)
      TraitBank.by_page(1)
    end

    it "finds the predicate" do
      expect(TraitBank).to receive(:query).with(/:predicate.*predicate:Term/)
      TraitBank.by_page(1)
    end

    it "optionally finds the object term" do
      expect(TraitBank).to receive(:query).with(/OPTIONAL MATCH.*:object_term.*object_term:Term/)
      TraitBank.by_page(1)
    end

    it "optionally finds the units term" do
      expect(TraitBank).to receive(:query).with(/OPTIONAL MATCH.*:units_term.*units:Term/)
      TraitBank.by_page(1)
    end

    it "calls .build_trait_array" do
      expect(TraitBank).to receive(:build_trait_array) { :results }
      expect(TraitBank.by_page(1)).to eq(:results)
    end
  end

  describe ".by_predicate" do
    let(:predicate) { "http://foo.bar/baz" }
    before do
      allow(TraitBank).to receive(:query) { }
      allow(TraitBank).to receive(:build_trait_array) { :result_set }
    end

    it "finds a page" do
      expect(TraitBank).to receive(:query).with(/page:Page/)
      TraitBank.by_predicate(predicate)
    end

    it "finds traits" do
      expect(TraitBank).to receive(:query).with(/:trait.*trait:Trait/)
      TraitBank.by_predicate(predicate)
    end

    it "finds the supplier resource" do
      expect(TraitBank).to receive(:query).with(/:supplier.*resource:Resource/)
      TraitBank.by_predicate(predicate)
    end

    it "finds the predicate" do
      expect(TraitBank).to receive(:query).with(/:predicate.*predicate:Term/)
      TraitBank.by_predicate(predicate)
    end

    it "optionally finds the object term" do
      expect(TraitBank).to receive(:query).with(/OPTIONAL MATCH.*:object_term.*object_term:Term/)
      TraitBank.by_predicate(predicate)
    end

    it "optionally finds the units term" do
      expect(TraitBank).to receive(:query).with(/OPTIONAL MATCH.*:units_term.*units:Term/)
      TraitBank.by_predicate(predicate)
    end

    it "calls .build_trait_array" do
      expect(TraitBank).to receive(:build_trait_array) { :results }
      expect(TraitBank.by_predicate(predicate)).to eq(:results)
    end

    it "adds measurement sort to the query when specified" do
      expect(TraitBank).to receive(:query).with(/trait.normal_measurement/)
      TraitBank.by_predicate(predicate, sort: "MEASurement")
    end

    it "adds default sort to the query by default" do
      expect(TraitBank).to receive(:query).with(/trait\.literal, object_term\.name, trait\.normal_measurement/)
      TraitBank.by_predicate(predicate)
    end

    it "does NOT add desc to the query by default" do
      expect(TraitBank).not_to receive(:query).with(/ desc/i)
      TraitBank.by_predicate(predicate)
    end

    it "DOES add desc to the query when specified" do
      expect(TraitBank).to receive(:query).with(/ desc/i)
      TraitBank.by_predicate(predicate, sort_dir: "DEsc")
    end
  end
end
