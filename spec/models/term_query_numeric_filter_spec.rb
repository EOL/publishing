require 'rails_helper'

RSpec.describe TermQueryNumericFilter do
  describe "validations" do
    it { should validate_presence_of(:value) }
    it { should validate_presence_of(:op) }
    it { should validate_presence_of(:units_uri) }
    it { should validate_presence_of(:pred_uri) }
    it { should validate_presence_of(:term_query) }
  end
end
