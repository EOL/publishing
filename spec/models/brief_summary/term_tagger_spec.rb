require 'rails_helper'

RSpec.describe('BriefSummary::TermTagger') do
  def mock_term_tracker

    tracker
  end

  let(:term_tracker) { mock_term_tracker }

  describe('#tag') do
    it 'returns a tag string with the correct toggle id' do
      label = 'Term Name'
      predicate = instance_double('TermNode')
      term = instance_double('TermNode')
      source = 'trait_source'
      toggle_id = 'toggle-id-20'
      expected = "<span class='a term-info-a' id='toggle-id-20'>Term Name</span>"

      tracker = instance_double('BriefSummary::TermTracker')
      allow(tracker).to receive(:toggle_id).with(predicate, term, source) { toggle_id }

      view = double('view_helper')
      allow(view).to receive(:content_tag).with(:span, label, class: ['a', 'term-info-a'], id: toggle_id) { expected }

      tagger = BriefSummary::TermTagger.new(tracker, view)

      tag = tagger.tag(label, predicate, term, source)
      expect(tag).to eq(expected)
    end 

    it 'raises an error when called with a blank label' do
      tracker = instance_double('BriefSummary::TermTracker')
      allow(tracker).to receive(:toggle_id)

      view = double('view_helper')
      allow(view).to receive(:content_tag)

      term = instance_double('TermNode')

      tagger = BriefSummary::TermTagger.new(tracker, view)

      expect { tagger.tag('foo', nil, term, nil) }.not_to raise_error
      expect { tagger.tag('', nil, term, nil) }.to raise_error(TypeError)
      expect { tagger.tag(nil, nil, term, nil) }.to raise_error(TypeError)
    end
  end
end
