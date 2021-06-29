require 'rails_helper'

require 'brief_summary/term_tracker'

RSpec.describe('BriefSummary::TermTagger') do
  let(:tracker) { instance_double('BriefSummary::TermTracker') }
  let(:view) { double('view_helper') }
  subject(:tagger) { BriefSummary::TermTagger.new(tracker, view) }

  describe '::TAG_CLASSES' do
    it do
      classes = BriefSummary::TermTagger::TAG_CLASSES
      expect(classes.length).to eq(2)
      expect(classes).to include('a')
      expect(classes).to include('term-info-a')
    end
  end

  describe '.tag_class_str' do
    it { expect(BriefSummary::TermTagger.tag_class_str).to eq('a term-info-a') }
  end

  describe('#tag') do
    let(:label) { 'Term Name' }
    let(:predicate) { instance_double('TermNode') }
    let(:term) { instance_double('TermNode') }
    let(:source) { 'trait_source' }
    let(:toggle_id) { 'toggle-id-20' }
    let(:expected) { "<span class='a term-info-a' id='toggle-id-20'>Term Name</span>" }

    before do
      allow(tracker).to receive(:toggle_id).with(predicate, term, source) { toggle_id }
      allow(view).to receive(:content_tag).with(:span, label, class: BriefSummary::TermTagger::TAG_CLASSES, id: toggle_id) { expected }
    end

    it { expect(tagger.tag(label, predicate, term, source)).to eq(expected) }

    context 'when label is blank' do
      shared_examples 'blank label' do
        it { expect { tagger.tag(label, predicate, term, source) }.to raise_error(TypeError) }
      end

      context 'when label is nil' do
        let(:label) { nil }

        it_behaves_like 'blank label'
      end

      context "when label == ''" do
        let(:label) { '' }

        it_behaves_like 'blank label'
      end
    end
  end

  describe '#toggle_id' do
    let(:predicate) { instance_double('TermNode') }
    let(:term) { instance_double('TermNode') }
    let(:source) { 'source' }
    let(:result) { 'delegated-toggle-id' }
    
    before { expect(tracker).to receive(:toggle_id).with(predicate, term, source) { result } }

    it { expect(tagger.toggle_id(predicate, term, source)).to eq(result) }
  end
end

