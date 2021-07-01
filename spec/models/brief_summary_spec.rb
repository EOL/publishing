require 'rails_helper'

require 'brief_summary'
require 'brief_summary/builder'

RSpec.describe('BriefSummary') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:view) { double('view_helper') }
  let(:builder_klass) { class_double('BriefSummary::Builder').as_stubbed_const }
  let(:builder) { instance_double('BriefSummary::Builder') }
  let(:result) { instance_double('BriefSummary') }

  describe '.english' do
    before do
      allow(builder_klass).to receive(:new).with(page, view, BriefSummary::ENGLISH_SENTENCES, :en) { builder }
      allow(builder).to receive(:build) { result }
    end

    it { expect(BriefSummary.english(page, view)).to eq(result) }
  end

  describe '.other_langs' do
    let(:locale) { :fr }

    before do
      allow(builder_klass).to receive(:new).with(page, view, BriefSummary::OTHER_LANGS_SENTENCES, locale) { builder }
      allow(builder).to receive(:build) { result }
    end

    it { expect(BriefSummary.other_langs(page, view, locale)).to eq(result) }
  end
end

