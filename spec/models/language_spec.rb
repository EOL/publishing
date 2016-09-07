require 'rails_helper'

RSpec.describe Language do
  describe ".english" do
    it "has code 'eng'" do
      expect(Language.english.code).to eq("eng")
    end

    it "has group 'en'" do
      expect(Language.english.group).to eq("en")
    end
  end

  describe ".current" do
    it "calls I18n.locale" do
      expect(I18n).to receive(:locale) { "en" }
      Language.current
    end

    it "finds languages by group" do
      lang = create(:language, group: "foo")
      allow(I18n).to receive(:locale) { "foo" }
      expect(Language.current).to eq(lang)
    end
  end
end
