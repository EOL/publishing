require 'rails_helper'

RSpec.describe TermQueryPredicateFilter do
  describe "validations" do
    it { should validate_presence_of(:pred_uri) }
    it { should validate_presence_of(:term_query) }
  end
end
