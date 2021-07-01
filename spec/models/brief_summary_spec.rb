require 'rails_helper'
require 'brief_summary'
require 'brief_summary/result'

RSpec.describe('BriefSummary') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:view) { double('view_helper') }
  let(:locale) { :en }

  describe '.english' do
    let(:result_klass) { class_double('BriefSummary::Result').as_stubbed_const }
    let(:result) { instance_double('BriefSummary::Result') }

    before do
      allow(result_klass).to receive(:new).with(page, view, BriefSummary::ENGLISH_SENTENCES, :en) { result }
    end

    it { expect(BriefSummary.english(page, view)).to eq(result) }
  end
end
