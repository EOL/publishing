require 'rails_helper'

RSpec.describe TermQueryObjectTermObject do
  describe "validations" do
    it { should have_one(:term_query_filter) }
    it { should validate_presence_of(:uri) }
  end
end
