require 'rails_helper'

RSpec.describe TermQueryRangeFilter do
  describe "validations" do
    it { should have_one(:term_query_filter) }
    it { should validate_presence_of(:from_value) }
    it { should validate_presence_of(:to_value) }
    it { should validate_presence_of(:units_uri) }
  end
end
