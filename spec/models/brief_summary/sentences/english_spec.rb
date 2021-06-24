require 'rails_helper'
require 'brief_summary/page_decorator'
require 'brief_summary/sentences/helper'
require 'trait'

RSpec.describe('BriefSummary::Sentences::English') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:helper) { instance_double('BriefSummary::Sentences::Helper') }
  let(:page_name) { 'Page (page)' }
  let(:page_rank) { 'page_rank' }
  let(:matches) { instance_double('BriefSummary::ObjUriMatcher::Matches') }
  let(:match) { instance_double('BriefSummary::ObjUriMatcher::Match') }
  let(:match_trait) { instance_double('Trait') }
  subject(:sentences) { BriefSummary::Sentences::English.new(page, helper) }

  before do 
    allow(page).to receive(:full_name) { page_name }
    allow(page).to receive(:rank_name) { page_rank }
    allow(page).to receive(:a2) { nil }
  end

  describe '#below_family_taxonomy' do

    before do
      allow(page).to receive(:growth_habit_matches) { matches }
      allow(match).to receive(:trait) { match_trait }
    end
    
    context 'when page is not below_family?' do
      before { allow(page).to receive(:below_family?) { false } }

      it do
        result = sentences.below_family_taxonomy

        expect(result).to_not be_nil
        expect(result.valid?).to be false
      end
    end

    context 'when page.below_family?' do
      let(:a2) { 'page_family' }

      before do
        allow(page).to receive(:below_family?) { true }
        allow(matches).to receive(:first_of_type) { nil }
      end

      shared_examples 'valid input' do
        context 'when page.a2 is nil' do
          it { expect(sentences.below_family_taxonomy.value).to eq(expected + '.') }
        end

        context 'when page.a2 is present' do
          before { allow(page).to receive(:a2) { a2 } }

          it do
            expect(sentences.below_family_taxonomy.value).to eq(expected + ' in the family page_family.')
          end
        end
      end

      shared_examples 'species_of_x' do
        let(:expected) { 'Page (page) is a page_rank of <growth habit>' }

        before do
          allow(helper).to receive(:add_trait_val_to_fmt).with(
            'Page (page) is a page_rank of %s',
            match_trait
          ) { expected }
        end

        it_behaves_like 'valid input'
      end

      context 'when page has a :species_of_x growth_habit_match' do
        before do
          allow(matches).to receive(:first_of_type).with(:species_of_x) { match }
        end

        it_behaves_like 'species_of_x'
      end

      context 'when page has a :species_of_lifecycle_x growth_habit_match' do
        let(:term_node) { class_double('TermNode').as_stubbed_const }
        let(:lifecycle_pred) {  instance_double('TermNode') }

        before { allow(matches).to receive(:first_of_type).with(:species_of_lifecycle_x) { match } }

        context 'when page has a lifecycle_habit trait' do
          let(:lifecycle_trait) { instance_double('Trait') }
          let(:expected) { 'Page (page) is a page_rank of <lifecycle> <growth habit>' }
          before do
            allow(term_node).to receive(:find_by_alias).with('lifecycle_habit') { lifecycle_pred }
            allow(page).to receive(:first_trait_for_predicate).with(lifecycle_pred) { lifecycle_trait }
            allow(helper).to receive(:add_trait_val_to_fmt).with('%s', lifecycle_trait) { '<lifecycle>' }
            allow(helper).to receive(:add_trait_val_to_fmt).with('Page (page) is a page_rank of <lifecycle> %s', match_trait) { expected }
          end

          it_behaves_like 'valid input'
        end    

        context "when page doesn't have a lifecycle_habit trait" do
          before do
            allow(term_node).to receive(:find_by_alias).with('lifecycle_habit') { lifecycle_pred }
            allow(page).to receive(:first_trait_for_predicate).with(lifecycle_pred) { nil }
          end

          it_behaves_like 'species_of_x'
        end
      end

      context 'when page has a :species_of_x_a1 growth_habit_match' do
        let(:expected) { 'Page (page) is a page_rank of <x> page_ancestor' }

        before do
          allow(matches).to receive(:first_of_type).with(:species_of_x_a1) { match }
          allow(page).to receive(:a1) { 'page_ancestor' }
          allow(helper).to receive(:add_trait_val_to_fmt).with('Page (page) is a page_rank of %s page_ancestor', match_trait) { expected }
        end

        it_behaves_like 'valid input'
      end

      context 'when page has no relevant growth_habit_match' do
        let(:expected) { 'Page (page) is a page_rank of page_ancestor' }

        before { allow(page).to receive(:a1) { 'page_ancestor' } }

        it_behaves_like 'valid input'
      end
    end
  end

  describe '#descendants' do
    let(:desc_info) { instance_double('Page::DescInfo') }

    context "when page isn't above_family?" do
      before do 
        allow(page).to receive(:above_family?) { false }
        allow(page).to receive(:desc_info) { desc_info }
      end

      it { expect(sentences.descendants).to_not be_valid }
    end

    context 'when page is above_family?' do
      before { allow(page).to receive(:above_family?) { true } }

      context 'when page.desc_info is nil' do
        before { allow(page).to receive(:desc_info) { nil } }

        it { expect(sentences.descendants).to_not be_valid }
      end

      context 'when page.desc_info is present' do
        let(:species) { 10 }
        let(:genera) { 5 }
        let(:families) { 1 }
        let(:genus_part) { '<genus/genera>' }
        let(:family_part) { '<family/families>' }

        before do
          allow(desc_info).to receive(:genus_count) { genera }
          allow(desc_info).to receive(:family_count) { families }
          allow(page).to receive(:desc_info) { desc_info }
          allow(page).to receive(:name) { '<page>' }
          allow(helper).to receive(:pluralize).with(genera, 'genus', 'genera') { "#{genera} #{genus_part}" }
          allow(helper).to receive(:pluralize).with(families, 'family', 'families') { "#{families} #{family_part}" }
        end

        shared_examples 'valid input' do
          before do
            allow(desc_info).to receive(:species_count) { species }
          end

          it { expect(sentences.descendants.value).to eq(expected) }
        end

        context 'when species_count == 0' do
          let(:species) { 0 }
          let(:expected) { "There are 0 species of <page>, in 5 #{genus_part} and 1 #{family_part}." }

          it_behaves_like 'valid input'
        end

        context 'when species_count == 1' do
          let(:species) { 1 }
          let(:expected) { "There is 1 species of <page>, in 5 #{genus_part} and 1 #{family_part}." }

          it_behaves_like 'valid input'
        end

        context 'when species_count > 1' do
          let(:species) { 10 }
          let(:expected) { "There are 10 species of <page>, in 5 #{genus_part} and 1 #{family_part}." }

          it_behaves_like 'valid input'
        end
      end
    end
  end

  describe '#first_appearance' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:fossil_pred) { instance_double('TermNode') }
    let(:trait) { instance_double('Trait') }
    let(:expected) { 'This page_rank has been around since the <era>.' }

    before do 
      allow(page).to receive(:above_family?) { true }
      allow(term_node).to receive(:find_by_alias).with('fossil_first') { fossil_pred }
      allow(page).to receive(:first_trait_for_predicate).with(
        fossil_pred, 
        with_object_term: true
      ) { trait }
      allow(helper).to receive(:add_trait_val_to_fmt).with(
        'This page_rank has been around since the %s.',
        trait
      ) { expected }
    end

    context 'with valid input' do
      it { expect(sentences.first_appearance.value).to eq(expected) }
    end

    context "when page doesn't have a fossil_first_trait" do
      before { allow(page).to receive(:first_trait_for_predicate).with(fossil_pred, with_object_term: true) { nil } }

      it { expect(sentences.first_appearance).to_not be_valid }
    end

    context "when page isn't above_family?" do
      before { allow(page).to receive(:above_family?) { false } }

      it { expect(sentences.first_appearance).to_not be_valid }
    end
  end

  shared_examples 'genus_and_below growth form' do
    before do
      allow(page).to receive(:genus_or_below?) { true }
      allow(page).to receive(:growth_habit_matches) { matches }
      allow(matches).to receive(:first_of_type).with(type) { match }
      allow(match).to receive(:trait) { match_trait }
      allow(helper).to receive(:add_trait_val_to_fmt).with(fstr, match_trait) { expected }
    end

    context 'with valid input' do
      it { expect(sentences.send(method).value).to eq(expected) }
    end

    context "when page isn't genus_or_below?" do
      before { allow(page).to receive(:genus_or_below?) { false } }
      it { expect(sentences.send(method)).to_not be_valid }
    end

    context "when page doesn't have a <type> growth_habit_match" do
      before { allow(matches).to receive(:first_of_type).with(type) { nil } }
      it { expect(sentences.send(method)).to_not be_valid }
    end
  end

  describe '#is_an_x_growth_form' do
    let(:expected) { 'They are <trait_val>s.' }
    let(:fstr) { 'They are %ss.' }
    let(:method) { :is_an_x_growth_form }
    let(:type) { :is_an_x }

    it_behaves_like 'genus_and_below growth form'
  end

  describe '#has_an_x_growth_form' do
    let(:method) { :has_an_x_growth_form }
    let(:type) { :has_an_x_growth_form }
    let(:match_trait_obj) { instance_double('TermNode') }

    before { allow(match_trait).to receive(:object_term) { match_trait_obj } }

    context 'when the object_term name begins with a consonant' do
      let(:expected) { 'They have a blue growth form.' }
      let(:fstr) { 'They have a %s growth form.' }

      before { allow(match_trait_obj).to receive(:name) { 'blue' } }

      it_behaves_like 'genus_and_below growth form'
    end

    context 'when the object_term name begins with a vowel' do
      let(:expected) { 'They have an orange growth form.' }
      let(:fstr) { 'They have an %s growth form.' }

      before { allow(match_trait_obj).to receive(:name) { 'orange' } }

      it_behaves_like 'genus_and_below growth form'
    end
  end
end
