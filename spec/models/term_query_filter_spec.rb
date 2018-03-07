require 'rails_helper'

RSpec.describe TermQueryFilter do
  it { should belong_to(:term_query) }
  it { should validate_presence_of(:term_query) }
  it { should validate_presence_of(:pred_uri)   }
  it { should validate_presence_of(:op) }

  context "when op is is_obj" do
    let(:filter) { create(:term_query_filter_is_obj) }

    it "should be valid" do
      expect(filter).to be_valid
    end

    it "should validate presence of obj_uri" do
      filter.obj_uri = nil
      expect(filter).to be_invalid
    end
  end

  RSpec.shared_examples "numeric" do |op, num_val2|
    let(:filter) do
      create(:term_query_filter, {
        :op => op,
        :num_val1 => 1.3,
        :num_val2 => num_val2,
        :units_uri => "units_uri"
      })
    end

    it "should be valid" do
      expect(filter).to be_valid
    end

    it "should validate presence of num_val1" do
      filter.num_val1 = nil
      expect(filter).to be_invalid
    end

    it "should validate presence of units_uri" do
      filter.units_uri = nil
      expect(filter).to be_invalid
    end

    if num_val2
      it "should validate presence of num_val2" do
        filter.num_val2 = nil
        expect(filter).to be_invalid
      end
    end
  end

  include_examples "numeric", :eq, nil
  include_examples "numeric", :gt, nil
  include_examples "numeric", :lt, nil
  include_examples "numeric", :range, 2.0
end
