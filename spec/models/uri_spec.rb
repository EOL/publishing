require 'rails_helper'

RSpec.describe Uri do
  describe ".is_uri?" do
    it "invokes URI::regexp for match" do
      string = double(String)
      expect(string).to receive(:=~).with(URI::regexp) { :that }
      expect(Uri.is_uri?(string)).to eq(:that)
    end
  end
end
