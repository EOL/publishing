require 'rails_helper'

RSpec.describe TermQueryFilter do
  describe "validations" do
    it { should belong_to(:term_query) }
    it { should validate_presence_of(:term_query) }
    it { should validate_presence_of(:pred_uri) }
    it { should belong_to(:object) }
    it { should validate_presence_of(:object) }
  end
end
