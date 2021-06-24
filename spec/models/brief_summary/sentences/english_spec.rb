require 'rails_helper'

RSpec.describe('BriefSummary::Sentences::English') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:helper) { instance_double('BriefSummary::Sentences::Helper') }
  let(:page_name) { 'Page (page)' }
  let(:page_rank) { 'page_rank' }
  subject(:sentences) { BriefSummary::Sentences::English.new(page, helper) }

  before do 
    allow(page).to receive(:full_name) { page_name }
    allow(page).to receive(:rank_name) { page_rank }
    allow(page).to receive(:a2) { nil }
  end

  describe 'below_family_taxonomy' do
    let(:matches) { instance_double('BriefSummary::ObjUriMatcher::Matches') }
    let(:match) { instance_double('BriefSummary::ObjUriMatcher::Match') }
    let(:match_trait) { instance_double('Trait') }

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
end
