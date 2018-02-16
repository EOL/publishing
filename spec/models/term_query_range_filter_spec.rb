require 'rails_helper'

RSpec.describe TermQueryRangeFilter do
  describe "validations" do
    it { should validate_presence_of(:from_value) }
    it { should validate_presence_of(:to_value) }
    it { should validate_presence_of(:units_uri) }
    it { should validate_presence_of(:pred_uri) }
    it { should validate_presence_of(:term_query) }
  end
end
