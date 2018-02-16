require 'rails_helper'

RSpec.describe TermQueryObjectTermFilter do
  describe "validations" do
    it { should have_one(:term_query_filter) }
    it { should validate_presence_of(:uri) }
    it { should validate_presence_of(:pred_uri) }
  end
end
