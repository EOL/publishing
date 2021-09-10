require 'rails_helper'

RSpec.describe('BriefSummary::ObjUriGroupMatcher::Matches') do
  # regression test
  describe('#has_type?') do
    let(:match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
    let(:uri) { 'uri' }
    let(:type) { :type }
    subject(:matches) { BriefSummary::ObjUriGroupMatcher::Matches.new([match]) }

    before do
      allow(match).to receive(:uri) { uri }
      allow(match).to receive(:type) { type }
    end

    it { expect(matches.has_type?(type)).to eq(true) }

    context('when the last match of a given type is removed') do
      let(:match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
      let(:uri) { 'uri' }
      let(:type) { :type }
      subject(:matches) { BriefSummary::ObjUriGroupMatcher::Matches.new([match]) }

      before do
        allow(match).to receive(:uri) { uri }
        allow(match).to receive(:type) { type }
      end
      
      it do
        matches.remove(match)
        expect(matches.has_type?(type)).to eq(false)
      end
    end
  end
end

