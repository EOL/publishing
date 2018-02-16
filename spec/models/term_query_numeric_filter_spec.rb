require 'rails_helper'

RSpec.describe TermQueryNumericFilter do
  describe "validations" do
    it { should have_one(:term_query_filter) }
    it { should validate_presence_of(:value) }
    it { should validate_presence_of(:op) }
    it { should validate_presence_of(:units_uri) }
  end
end
