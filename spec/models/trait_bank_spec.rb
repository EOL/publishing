require "rails_helper"

RSpec.describe TraitBank do
  let(:conn) { instance_double(Neography::Rest) }

  describe ".connection" do
    before do
      begin
        TraitBank.class_eval { remove_instance_variable(:@connection) }
      rescue NameError
        nil # This is fine; it wasn't defined.
      end
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
      expect(conn).to receive(:execute_query).with("this") { :results }
      allow(TraitBank).to receive(:connection) { conn }
      expect(TraitBank.query("this")).to eq(:results)
    end

    it "detects timeouts and sleeps before retrying" do
      expect(conn).to receive(:execute_query).exactly(2).times.and_raise(Excon::Error::Timeout.new)
      expect(TraitBank).to receive(:sleep).with(1)
      allow(TraitBank).to receive(:connection) { conn }
      expect { TraitBank.query("this") }.to raise_error(Excon::Error::Timeout)
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

  describe ".count" do
    it "should return a count" do
      result = { "data" => [[123, 234], :not_this] }
      expect(TraitBank).to receive(:query).with(/RETURN count/) { result }
      expect(TraitBank.count).to eq(123)
    end
  end

  describe ".predicate_count" do
    it "should return a count" do
      result = { "data" => [[234, 456], :not_this] }
      expect(TraitBank).to receive(:query).with(/RETURN count/) { result }
      expect(TraitBank.predicate_count).to eq(234)
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
        with(/:Trait.*resource_pk: \"traitIDHere\"/) { }
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
      expect(TraitBank).to receive(:query).with(/MATCH.*:object_term.*:Term/) { }
      TraitBank.by_trait(full_id)
    end

    it "query with the optional units term" do
      expect(TraitBank).to receive(:query).with(/MATCH.*:units_term.*:Term/) { }
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
      expect(TraitBank).to receive(:query).with(/MATCH.*:object_term.*object_term:Term/)
      TraitBank.by_page(1)
    end

    it "optionally finds the units term" do
      expect(TraitBank).to receive(:query).with(/MATCH.*:units_term.*units:Term/)
      TraitBank.by_page(1)
    end

    it "calls .build_trait_array" do
      expect(TraitBank).to receive(:build_trait_array) { :results }
      expect(TraitBank.by_page(1)).to eq(:results)
    end
  end

  describe ".by_predicate" do
    let(:uri) { "http://foo.bar/baz" }
    before do
      allow(TraitBank).to receive(:query) { }
      allow(TraitBank).to receive(:build_trait_array) { :result_set }
    end

    it "finds a page" do
      expect(TraitBank).to receive(:query).with(/page:Page/)
      TraitBank.by_predicate(uri)
    end

    it "finds traits" do
      expect(TraitBank).to receive(:query).with(/:trait.*trait:Trait/)
      TraitBank.by_predicate(uri)
    end

    it "finds the supplier resource" do
      expect(TraitBank).to receive(:query).with(/:supplier.*resource:Resource/)
      TraitBank.by_predicate(uri)
    end

    it "finds the predicate" do
      expect(TraitBank).to receive(:query).with(/:predicate.*predicate:Term/)
      TraitBank.by_predicate(uri)
    end

    it "optionally finds the object term" do
      expect(TraitBank).to receive(:query).with(/MATCH.*info_term:Term/)
      TraitBank.by_predicate(uri)
    end

    it "optionally finds the units term" do
      expect(TraitBank).to receive(:query).with(/MATCH.*info_term:Term/)
      TraitBank.by_predicate(uri)
    end

    it "calls .build_trait_array" do
      expect(TraitBank).to receive(:build_trait_array) { :results }
      expect(TraitBank.by_predicate(uri)).to eq(:results)
    end

    it "adds measurement sort to the query when specified" do
      expect(TraitBank).to receive(:query).with(/trait.normal_measurement/)
      TraitBank.by_predicate(uri, sort: "MEASurement")
    end

    it "adds default sort to the query by default" do
      expect(TraitBank).to receive(:query).with(/LOWER\(info_term\.name.*trait\.normal_measurement.*LOWER\(trait\.literal/)
      TraitBank.by_predicate(uri)
    end

    it "does NOT add desc to the query by default" do
      expect(TraitBank).not_to receive(:query).with(/ desc/i)
      TraitBank.by_predicate(uri)
    end

    it "DOES add desc to the query when specified" do
      expect(TraitBank).to receive(:query).with(/ desc/i)
      TraitBank.by_predicate(uri, sort_dir: "DEsc")
    end

    it "can look up object terms" do
      expect(TraitBank).to receive(:query).with(/where \w+\.uri = "#{uri}"/i)
      TraitBank.by_object_term_uri(uri)
    end

    it "can count object terms" do
      expect(TraitBank).to receive(:query).with(/where \w+\.uri = "#{uri}"/i) { { "data" => [[]] } }
      TraitBank.by_object_term_count(uri)
    end

    it "can add metadata" do
      expect(TraitBank).to receive(:query).with(/:metadata.*:units_term.*:object_term/i)
      TraitBank.by_predicate(uri, meta: true)
    end

    it "can add clade" do
      expect(TraitBank).to receive(:query).with(/where page.page_id = 123432 or ancestor.page_id = 123432/i)
      TraitBank.by_predicate(uri, clade: 123432)
    end
  end

  describe ".by_object_term_uri" do
    let(:term_uri) { "http://foo.bar/baz" }
    before do
      allow(TraitBank).to receive(:query) { }
      allow(TraitBank).to receive(:build_trait_array) { :result_set }
    end

    it "finds a quoted URI" do
      expect(TraitBank).to receive(:query).with(/Term[^M]+WHERE predicate.uri = \"#{term_uri}\"/)
      TraitBank.by_predicate(term_uri)
    end

    it "calls .build_trait_array" do
      expect(TraitBank).to receive(:build_trait_array) { :results }
      expect(TraitBank.by_page(term_uri)).to eq(:results)
    end
  end

  # NOTE: there's a lot we could test here, but it all feels very ... "internal"
  # and too fragile to bother writing as a spec. That said, it's important that
  # we use a consistent ID format, so let's test that:
  describe ".build_trait_array" do
    it "should produce the expected ID format" do
      results = {"columns" => ["resource", "trait"],
        "data" => [[
            { "metadata" => { "id" => "abc123" }, "data" => {"resource_id"=>"TheRes_ID"} },
            { "metadata" => { "id" => "abc123" }, "data" => {"resource_pk"=>"ResPKHere"} }
          ]]}
      expect(TraitBank.build_trait_array(results).first[:id]).
        to eq("trait--TheRes_ID--ResPKHere")
    end
  end

  describe ".terms" do
    it "orders the results by name (then uri)" do
      allow(TraitBank).to receive(:query) { { "data" => [] } }
      expect(TraitBank).to receive(:query).with(/order by lower\(term.name\), lower\(term.uri\)/i)
      TraitBank.terms
    end
  end

  describe "convenience aliases to .by_predicate" do
    it "counts predicates" do
      expect(TraitBank).to receive(:term_search).with({predicate: :abc, count: true })
      TraitBank.by_predicate_count(:abc)
    end

    it "by object term uri" do
      expect(TraitBank).to receive(:term_search).with({ object_term: :bcd })
      TraitBank.by_object_term_uri(:bcd)
    end

    it "count by object term uri" do
      expect(TraitBank).to receive(:term_search).with({ object_term: :def, count: true })
      TraitBank.by_object_term_count(:def)
    end
  end

  describe ".search_predicate_terms" do
    it "uses the important parts of query" do
      expect(TraitBank).to receive(:query).
        with(/:predicate\]->\(\w+:term\).*name =\~ .*trmy.*order by lower\(\w+\.name\)/i) { { "data" => [[{ "data" => :this }]] } }
      expect(TraitBank.search_predicate_terms(:trmy)).to eq([:this])
    end
  end

  describe ".count_predicate_terms" do
    it "uses the important parts of query" do
      expect(TraitBank).to receive(:query).
        with(/:predicate\]->\(\w+:term\).*name =\~ .*trmy.*count\(distinct\(/i) { { "data" => [[543]] } }
      expect(TraitBank.count_predicate_terms(:trmy)).to eq(543)
    end
  end

  describe ".search_object_terms" do
    it "uses the important parts of query" do
      expect(TraitBank).to receive(:query).
        with(/:object_term\]->\(\w+:term\).*name =\~ .*wordy.*order by lower\(\w+\.name\)/i) { { "data" => [[{ "data" => :tother }]] } }
      expect(TraitBank.search_object_terms(:wordy)).to eq([:tother])
    end
  end

  describe ".count_object_terms" do
    it "uses the important parts of query" do
      expect(TraitBank).to receive(:query).with(/:object_term\]->\(\w+:term\).*name =\~ .*trmy.*count\(distinct\(/i) { { "data" => [[876]] } }
      expect(TraitBank.count_object_terms(:trmy)).to eq(876)
    end
  end

  describe ".page_exists?" do
    it "matches page ids" do
      expect(TraitBank).to receive(:query).with(/:page {\s*page_id: 1234543/i) { { "data" => [] } }
      TraitBank.page_exists?(1234543)
    end
  end

  describe ".resources" do
    it "pulls the resources from a set of traits" do
      res1 = instance_double(Resource, id: 123)
      res2 = instance_double(Resource, id: 234)
      res3 = instance_double(Resource, id: 345)
      expect(Resource).to receive(:where).
        with(id: [123, 234, 345]) { [res1, res2, res3] }
      traits = [ { resource_id: 123 }, { resource_id: 234 },
        { resource_id: 345 } ]
      expect(TraitBank.resources(traits))
    end
  end

  describe ".create_page" do
    before do
      allow(TraitBank).to receive(:page_exists?) { }
    end

    it "returns a page that already exists" do
      expect(TraitBank).to receive(:page_exists?).with(6754) { :this_page }
      expect(TraitBank.page_exists?(6754)).to eq(:this_page)
    end

    # Ugh. There's a long conversation in the RSpec community about how you
    # cannot call #receive_method_chain more than once, so you MUST break it
    # down like this:
    it "creates a node if no page exists" do
      connection = instance_double(Neography::Rest)
      allow(TraitBank).to receive(:connection).at_least(1).times { connection }
      expect(connection).to receive(:create_node).
        with(page_id: 888854) { :a_page }
      expect(connection).to receive(:add_label).
        with(:a_page, "Page") { }
      expect(TraitBank.create_page(888854)).to eq(:a_page)
    end
  end

  describe ".find_resource" do
    it "runs the expected query" do
      expect(TraitBank).to receive(:query).with(/:resource { resource_id: 777555 }/i) { { "data" => [:hi] } }
      expect(TraitBank.find_resource(777555)).to eq(:hi)
    end
  end

  # NOTE: this is rather a complicated method... but parts of it are tested "in
  # situ" elsewhere, so I'm only going to focus on the usual cases here:
  describe ".results_to_hashes" do
    it "handles nil values" do
      results = {"columns" => ["trait", "foo"], "data" => [
        [ { "metadata" => { "id" => "abc1" }, "data" => {} },
          nil
        ]
      ] }
      expect(TraitBank.results_to_hashes(results).first[:foo]).to be_nil
    end

    it "handles metadata over multiple lines" do
      results = {"columns" => ["trait", "meta_foo"], "data" => [
        [ { "metadata" => { "id" => "abc2" }, "data" => {} },
          { "data" => :whatever }
        ],
        [ { "metadata" => { "id" => "abc2" }, "data" => {} },
          { "data" => :second_value }
        ]
      ] }
      expect(TraitBank.results_to_hashes(results).first[:meta_foo]).
        to eq([:whatever, :second_value])
    end

    it "symbolizes hash values" do
      results = {"columns" => ["trait", "foo"], "data" => [
        [ { "metadata" => { "id" => "abc1" }, "data" => {} },
          { "data" => { "this_key" => "value" } }
        ]
      ] }
      expect(TraitBank.results_to_hashes(results).first[:foo]).
        to eq({ this_key: "value" })
    end

    it "symbolizes all hashes in array values" do
      results = {"columns" => ["trait", "foo"], "data" => [
        [ { "metadata" => { "id" => "abc2" }, "data" => {} },
          { "data" => { "first" => "A" } }
        ],
        [ { "metadata" => { "id" => "abc2" }, "data" => {} },
          { "data" => { "second" => "B" } }
        ]
      ] }
      expect(TraitBank.results_to_hashes(results).first[:foo]).
        to eq([{ first: "A" }, { second: "B" }])
    end
  end

  # NOTE: this is (also) rather a complicated method... but parts of it are
  # tested "in situ" elsewhere, so I'm only going to focus on the usual cases
  # here:
  describe ".results_to_hashes" do
    it "reveals missing resource_id" do
      allow(TraitBank).to receive(:results_to_hashes) do
        [{}]
      end
      expect(TraitBank.build_trait_array(nil).first[:resource_id]).
        to eq("MISSING")
    end

    it "handles object terms" do
      allow(TraitBank).to receive(:results_to_hashes) do
        [{info_term: { this: "thing" }, info_type: "object_term" }]
      end
      expect(TraitBank.build_trait_array(nil).first[:object_term]).
        to eq({ this: "thing" })
    end

    it "handles unit terms" do
      allow(TraitBank).to receive(:results_to_hashes) do
        [{info_term: { that: "unit" }, info_type: "units_term" }]
      end
      expect(TraitBank.build_trait_array(nil).first[:units]).
        to eq({ that: "unit" })
    end

    it "returns metadata predicate, units term, and object term" do
      allow(TraitBank).to receive(:results_to_hashes) do
        [{meta: [{ some: :val }], meta_predicate: [:pred_1], meta_object_term: [:obj_1], meta_units_term: [:unit_1] }]
      end
      expect(TraitBank.build_trait_array(nil).first[:meta]).
        to eq([{ some: :val, predicate: :pred_1, object_term: :obj_1, units: :unit_1 }])
    end

    it "assigns the expected id" do
      allow(TraitBank).to receive(:results_to_hashes) do
        [{ resource: { resource_id: 777 }, trait: { resource_pk: "abc" }, page: { page_id: 453 } }]
      end
      expect(TraitBank.build_trait_array(nil).first[:id]).
        to eq("trait--777--abc--453")
    end
  end
end
