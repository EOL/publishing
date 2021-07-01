require 'rails_helper'

require 'brief_summary/result'
require 'brief_summary/sentences/result'

RSpec.describe('BriefSummary::Result') do
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
  let(:locale) { :en }
  let(:sentence_specs) do
    [
      BriefSummary::Result::SentenceSpec.new(:english, :english_sentence1),
      BriefSummary::Result::SentenceSpec.new(:any_lang, :any_lang_sentence1),
      BriefSummary::Result::SentenceSpec.new(:any_lang, :any_lang_sentence2),
      BriefSummary::Result::SentenceSpec.new(:english, :english_sentence2)
    ]
  end

  before do
    allow(tracker_klass).to receive(:new) { tracker }
    allow(tagger_klass).to receive(:new).with(tracker, view) { tagger }
    allow(helper_klass).to receive(:new).with(tagger, view) { helper }

    allow(english_klass).to receive(:new).with(page, helper) { english }
    allow(any_lang_klass).to receive(:new).with(page, helper, locale) { any_lang }
  end

  subject(:result) { BriefSummary::Result.new(page, view, sentence_specs, locale) }

  describe '#to_s' do
    context('when all sentences are valid?') do
      before do
        allow(english).to receive(:english_sentence1) { BriefSummary::Sentences::Result.valid('English1.') }
        allow(english).to receive(:english_sentence2) { BriefSummary::Sentences::Result.valid('English2.') }
        allow(any_lang).to receive(:any_lang_sentence1) { BriefSummary::Sentences::Result.valid('AnyLang1.') }
        allow(any_lang).to receive(:any_lang_sentence2) { BriefSummary::Sentences::Result.valid('AnyLang2.') }
      end

      it { expect(result.to_s).to eq("English1. AnyLang1. AnyLang2. English2.") }
    end

    context 'when some sentences are not valid?' do
      before do
        allow(english).to receive(:english_sentence1) { BriefSummary::Sentences::Result.valid('English1.') }
        allow(english).to receive(:english_sentence2) { BriefSummary::Sentences::Result.invalid }
        allow(any_lang).to receive(:any_lang_sentence1) { BriefSummary::Sentences::Result.invalid }
        allow(any_lang).to receive(:any_lang_sentence2) { BriefSummary::Sentences::Result.valid('AnyLang2.') }
      end

      it { expect(result.to_s).to eq("English1. AnyLang2.") }
    end

    context 'when sentences raise BadTraitError' do
      before do
        allow(english).to receive(:english_sentence1) { BriefSummary::Sentences::Result.valid('English1.') }
        allow(english).to receive(:english_sentence2).and_raise(BriefSummary::BadTraitError)
        allow(any_lang).to receive(:any_lang_sentence1) { BriefSummary::Sentences::Result.valid('AnyLang1.') }
        allow(any_lang).to receive(:any_lang_sentence2).and_raise(BriefSummary::BadTraitError)
      end

      it { expect(result.to_s).to eq('English1. AnyLang1.') }
    end

    context 'when no sentences are valid' do
      before do
        allow(english).to receive(:english_sentence1) { BriefSummary::Sentences::Result.invalid }
        allow(english).to receive(:english_sentence2) { BriefSummary::Sentences::Result.invalid }
        allow(any_lang).to receive(:any_lang_sentence1) { BriefSummary::Sentences::Result.invalid }
        allow(any_lang).to receive(:any_lang_sentence2) { BriefSummary::Sentences::Result.invalid }
      end

      it { expect(result.to_s).to eq('') }
    end
  end

  describe '#terms' do
    let(:result_terms) { instance_double('Array') }
    let(:sentences) { [BriefSummary::Result::SentenceSpec.new(:english, :sentence)] }

    before do 
      allow(english).to receive(:sentence) { BriefSummary::Sentences::Result.valid('Sentence.') }
      allow(tracker).to receive(:result_terms) { result_terms }
    end

    subject(:result) { BriefSummary::Result.new(page, view, sentences, locale) }

    it { expect(result.terms).to eq(result_terms) }
  end
end
