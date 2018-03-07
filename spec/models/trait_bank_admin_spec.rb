require "rails_helper"

RSpec.describe TraitBank::Admin do
  let(:conn) { instance_double(Neography::Rest) }

  describe ".setup" do
    it "calls .create_indexes and .create_constraints" do
      expect(TraitBank::Admin).to receive(:create_indexes)
      expect(TraitBank::Admin).to receive(:create_constraints)
      TraitBank::Admin.setup
    end
  end

  context "with stubbed queries" do
    before do
      allow(TraitBank::Admin).to receive(:query) { }
    end

    # NOTE: these may seem like relatively silly tests, but these Indexes are
    # really important.
    describe ".create_indexes" do
      it "creates page index" do
        expect(TraitBank::Admin).to receive(:query).with("CREATE INDEX ON :Page(page_id);")
        TraitBank::Admin.create_indexes
      end

      it "creates data index" do
        expect(TraitBank::Admin).to receive(:query).with("CREATE INDEX ON :Trait(resource_pk);")
        TraitBank::Admin.create_indexes
      end

      it "creates term index" do
        expect(TraitBank::Admin).to receive(:query).with("CREATE INDEX ON :Term(uri);")
        TraitBank::Admin.create_indexes
      end

      it "creates resource index" do
        expect(TraitBank::Admin).to receive(:query).with("CREATE INDEX ON :Resource(resource_id);")
        TraitBank::Admin.create_indexes
      end
    end

    # NOTE: these are LESS important than indexes, so I'm not testing them; just
    # the case of the failure, since that IS important.
    describe ".create_constraints" do
      it "handles existing contraints" do
        allow(TraitBank::Admin).to receive(:query)
        expect(TraitBank::Admin).to receive(:query).and_raise(Neography::NeographyError.new("already exists"))
        expect { TraitBank::Admin.create_constraints }.not_to raise_error
      end

      it "fails on any other error" do
        # NOTE the typo. ;)
        allow(TraitBank::Admin).to receive(:query)
        expect(TraitBank::Admin).to receive(:query).and_raise(Neography::NeographyError.new("already exits"))
        expect { TraitBank::Admin.create_constraints }.to raise_error(Neography::NeographyError)
      end
    end
  end
end
