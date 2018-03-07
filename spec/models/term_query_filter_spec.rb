require 'rails_helper'

RSpec.describe TermQueryFilter do
  it { should belong_to(:term_query) }
  it { should validate_presence_of(:term_query) }
  it { should validate_presence_of(:pred_uri)   }
  it { should validate_presence_of(:filter_type)       }

  context "when type is object_term" do
    let(:filter) { create(:term_query_filter_object_term) }

    it "should be valid" do
      expect(filter).to be_valid
    end

    it "should validate presence of obj_uri" do
      filter.obj_uri = nil
      expect(filter).to be_invalid
    end
  end

  context "when type is numeric" do
    let(:filter) { create(:term_query_filter_numeric) }

    it "should be valid" do
      expect(filter).to be_valid
    end

    it "should validate presence of num_op" do
      filter.num_op = nil
      expect(filter).to be_invalid
    end

    it "should validate presence of num_val1" do
      filter.num_val1 = nil
      expect(filter).to be_invalid
    end
  end

  context "when type is range" do
    let(:filter) { create(:term_query_filter_range) }

    it "should be valid" do
      expect(filter).to be_valid
    end

    it "should validate presence of num_val1" do
      filter.num_val1 = nil
      expect(filter).to be_invalid
    end

    it "should validate presence of num_val2" do
      filter.num_val2 = nil
      expect(filter).to be_invalid
    end
  end
end
