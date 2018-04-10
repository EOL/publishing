require 'rails_helper'

RSpec.describe Uri do
  describe ".is_uri?" do
    it "invokes URI::ABS_URI for match" do
      string = double(String)
      expect(string).to receive(:=~).with(URI::ABS_URI) { :that }
      expect(Uri.is_uri?(string)).to eq(:that)
    end
  end
end
