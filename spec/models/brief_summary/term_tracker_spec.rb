require 'rails_helper'

RSpec.describe('BriefSummary::TermTracker') do
  subject(:tracker) { BriefSummary::TermTracker.new }

  describe('#toggle_id') do
    it 'returns unique values' do
      term = instance_double('TermNode')
      ids = (1..10).map { |i| tracker.toggle_id(nil, term, nil) }
      expect(ids).to eql(ids.uniq)
    end

    context 'when term argument is nil' do
      it 'raises an error' do
        expect { tracker.toggle_id(nil, nil, nil) }.to raise_error(TypeError)
      end
    end
  end

  describe('#result_terms') do
    it "is empty when toggle_id hasn't been called" do
      expect(tracker.result_terms).to be_empty
    end

    it 'contains the correct ResultTerm for each toggle_id call' do
      Input = Struct.new(:predicate, :term, :source)

      inputs = [
        Input.new(instance_double('TermNode'), instance_double('TermNode'), nil),
        Input.new(nil, instance_double('TermNode'), 'source'),
        Input.new(nil, instance_double('TermNode'), nil)
      ]

      toggle_ids = inputs.map do |input| 
        tracker.toggle_id(input.predicate, input.term, input.source)
      end

      result_terms = tracker.result_terms

      expect(result_terms.length).to eq(inputs.length)

      inputs.each_with_index do |input, i|
        toggle_id = toggle_ids[i]
        result_term = result_terms[i]

        expect(result_term.predicate).to eq(input.predicate)
        expect(result_term.term).to eq(input.term)
        expect(result_term.source).to eq(input.source)
        expect(result_term.toggle_selector).to eq(toggle_id)
      end
    end
  end
end
