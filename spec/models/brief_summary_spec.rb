require 'rails_helper'

require 'brief_summary/sentences/english'
require 'brief_summary/sentences/any_lang'
require 'brief_summary'

RSpec.describe('BriefSummary') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:view) { double('view_helper') }
  let(:english_klass) { class_double('BriefSummary::Sentences::English').as_stubbed_const }
  let(:any_lang_klass) { class_double('BriefSummary::Sentences::AnyLang').as_stubbed_const }
  let(:helper_klass) { class_double('BriefSummary::Sentences::Helper').as_stubbed_const }
  let(:tracker_klass) { class_double('BriefSummary::TermTracker').as_stubbed_const }
  let(:tagger_klass) { class_double('BriefSummary::TermTagger').as_stubbed_const }
  let(:english) { instance_double('BriefSummary::Sentences::English') }
  let(:any_lang) { instance_double('BriefSummary::Sentences::AnyLang') }
  let(:helper) { instance_double('BriefSummary::Sentences::Helper') }
  let(:tracker) { instance_double('BriefSummary::TermTracker') }
  let(:tagger) { instance_double('BriefSummary::Tagger') }
  let(:result_terms) { instance_double('Array') }

  before do
    allow(tracker_klass).to receive(:new) { tracker }
    allow(tagger_klass).to receive(:new).with(tracker, view) { tagger }
    allow(helper_klass).to receive(:new).with(tagger, view) { helper }

    allow(english_klass).to receive(:new).with(page, helper) { english }
    allow(any_lang_klass).to receive(:new).with(page, helper, :en) { any_lang }
    allow(tracker).to receive(:result_terms) { result_terms }
  end

  describe '.english' do
    let(:methods) do
      [ 
        [any_lang, :family_and_above_taxonomy],
        [english, :descendants], 
        [english, :first_appearance],
        [english, :below_family_taxonomy],
        [english, :is_an_x_growth_form],
        [english, :has_an_x_growth_form],
        [any_lang, :extinction],
        [english, :conservation],
        [any_lang, :marine],
        [any_lang, :freshwater],
        [english, :native_range],
        [english, :found_in],
        [english, :landmark_children],
        [english, :plant_description],
        [english, :visits_flowers],
        [english, :flowers_visited_by],
        [any_lang, :fix_nitrogen],
        [english, :form1],
        [english, :form2],
        [english, :ecosystem_engineering],
        [english, :behavior],
        [english, :lifespan_size],
        [english, :reproduction_vw],
        [english, :reproduction_y],
        [english, :reproduction_x],
        [english, :reproduction_z],
        [english, :motility]
      ]
    end

    let(:values) { [] }
    subject(:summary) { BriefSummary.english(page, view) }

    before do
      methods.each do |pair|
        value = "Sentence: #{pair.second}."
        result = instance_double('BriefSummary::Result')
        allow(result).to receive(:valid?) { true }
        allow(result).to receive(:value) { value }
        allow(pair.first).to receive(pair.second) { result }
        values << value
      end
    end
        
    it { expect(summary.to_s).to eq(values.join(' ')) }
    it { expect(summary.terms).to eq(result_terms) }
  end
end
