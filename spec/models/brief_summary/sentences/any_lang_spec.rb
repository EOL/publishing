require 'rails_helper'

require 'trait'
require 'rank'
require 'brief_summary/page_decorator'

RSpec.describe('BriefSummary::Sentences::AnyLang') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:helper) { instance_double('BriefSummary::Sentences::Helper') }
  let(:rank) { instance_double('Rank') }
  subject(:sentences) { BriefSummary::Sentences::AnyLang.new(page, helper, locale) }

  before do
    allow(page).to receive(:rank) { rank }
  end

  describe '#family_and_above_taxonomy' do
    let(:full_name) { 'Pagename (pagename)' }
    let(:a1) { '<a>Ancestor</a>' }

    before do
      allow(page).to receive(:full_name) { full_name }
      allow(page).to receive(:a1) { a1 }
      allow(page).to receive(:family_or_above?) { true }
    end

    treat_as = Rank.treat_as
      .map { |v| v.first }
      .filter { |t| Rank.treat_as[t] <= Rank.treat_as[:r_family] }

    I18n.available_locales.each do |l|
      let(:locale) { l }

      context "when locale is #{l}" do
        treat_as.each do |t|
          context "when rank is #{t}" do
            before { allow(rank).to receive(:treat_as) { t } }

            it do
              expected = I18n.t(
                "brief_summary.taxonomy.family_above.#{t}", 
                locale: locale,
                name1: full_name,
                name2: a1
              )

              expect(sentences.family_and_above_taxonomy.value).to eq(expected)
            end
          end
        end
      end
    end

    context 'when page is not family_or_above?' do
      before { allow(page).to receive(:family_or_above?) { false } }

      it do
        sentences = BriefSummary::Sentences::AnyLang.new(page, helper, :en)
        expect(sentences.family_and_above_taxonomy).to_not be_valid
      end
    end
  end

  describe '#below_family_taxonomy' do
    let(:full_name) { '<pagename>' }
    let(:a1) { '<a1>' }
    let(:a2) { '<a1>' }
    let(:locale) { :en }

    before do
      allow(page).to receive(:a1) { a1 }
      allow(page).to receive(:full_name) { full_name }
    end

    context 'when not page.below_family?' do
      before { allow(page).to receive(:below_family?) { false } }

      it { expect(sentences.below_family_taxonomy).to_not be_valid }
    end


    context 'when page.below_family?' do
      before { allow(page).to receive(:below_family?) { true } }

      I18n.available_locales.each do |locale|
        context "when locale is #{locale}" do
          let(:locale) { locale }


          Rank.treat_as.map { |v| v.first }.filter { |t| Rank.treat_as[t] > Rank.treat_as[:r_family] }.each do |treat_as|
            context "when rank.treat_as is #{treat_as}" do
              before { allow(rank).to receive(:treat_as) { treat_as } }

              context 'when a2 is present' do
                before { allow(page).to receive(:a2) { a2 } }

                it do
                  expect(sentences.below_family_taxonomy.value).to eq(I18n.t(
                    "brief_summary.taxonomy.below_family.with_family.#{treat_as}",
                    name1: full_name,
                    name2: a1,
                    name3: a2,
                    locale: locale
                  ))
                end
              end

              context 'when a2 is not present' do
                before { allow(page).to receive(:a2) { nil } }

                it do
                  expect(sentences.below_family_taxonomy.value).to eq(I18n.t(
                    "brief_summary.taxonomy.below_family.without_family.#{treat_as}",
                    name1: full_name,
                    name2: a1,
                    locale: locale
                  ))
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#extinction' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:object_term) { instance_double('TermNode') }
    let(:trait) { instance_double('Trait') }
    let(:toggle_id) { 'toggle-id-1' }

    before do
      allow(term_node).to receive(:find_by_alias).with('extinction_status') { predicate }
      allow(trait).to receive(:object_term) { object_term }
      allow(helper).to receive(:toggle_id).with(predicate, object_term, nil) { toggle_id }
      allow(page).to receive(:extinct?) { true }
      allow(page).to receive(:genus_or_below?) { true }
      allow(rank).to receive(:treat_as) { 'r_species' }
    end
    
    context 'when page.extinct?' do
      before do 
        allow(page).to receive(:extinct_trait) { trait }
      end

      I18n.available_locales.each do |locale|
        context "when locale is #{locale}" do
          let(:locale) { locale }

          Rank.treat_as
            .map { |v| v.first }
            .filter { |t| Rank.treat_as[t] >= Rank.treat_as[:r_genus] }.each do |treat_as|
              context "when rank is #{treat_as}" do
                let(:key) { "extinction.#{treat_as}_html" }

                before { allow(rank).to receive(:treat_as) { treat_as } }

                it do 
                  expect(sentences.extinction.value).to eq(I18n.t(
                    "brief_summary.#{key}",
                    class_str: BriefSummary::TermTagger.tag_class_str,
                    id: toggle_id,
                    locale: locale
                  ))
                end
              end
          end
        end
      end
    end

    context 'when page is not extinct?' do
      let(:locale) { :en }

      before { allow(page).to receive(:extinct?) { false } }
      it { expect(sentences.extinction).to_not be_valid }
    end

    context 'when page is not genus_or_below?' do
      let(:locale) { :en }

      before { allow(page).to receive(:genus_or_below?) { false } } 
      it { expect(sentences.extinction).to_not be_valid }
    end
  end

  describe '#marine' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:object_term) { instance_double('TermNode') }
    let(:toggle_id) { 'toggle-id-1' }

    before do 
      allow(page).to receive(:marine?) { true }
      allow(page).to receive(:genus_or_below?) { true }
      allow(term_node).to receive(:find_by_alias).with('habitat') { predicate }
      allow(term_node).to receive(:find_by_alias).with('marine') { object_term }
      allow(helper).to receive(:toggle_id).with(predicate, object_term, nil) { toggle_id }
    end

    I18n.available_locales.each do |locale|
      context "when locale is #{locale}" do
        let(:locale) { locale } 

        it do 
          expect(sentences.marine.value).to eq(I18n.t(
            'brief_summary.marine_html',
            class_str: BriefSummary::TermTagger.tag_class_str,
            id: toggle_id,
            locale: locale
          ))
        end

        context "when page isn't genus_or_below?" do
          before { allow(page).to receive(:genus_or_below?) { false } }

          it { expect(sentences.marine).to_not be_valid }
        end
      end
    end

    context "when page isn't marine" do
      let(:locale) { :en }

      before { allow(page).to receive(:marine?) { false } }

      it { expect(sentences.marine).to_not be_valid }
    end
  end

  describe '#freshwater' do
    let(:trait) { instance_double('Trait') }
    let(:predicate) { instance_double('TermNode') }
    let(:object_term) { instance_double('TermNode') }
    let(:toggle_id) { 'toggle-id-1' }

    before do
      allow(page).to receive(:freshwater?) { true }
      allow(page).to receive(:freshwater_trait) { trait }
      allow(page).to receive(:genus_or_below?) { true }
      allow(trait).to receive(:predicate) { predicate }
      allow(trait).to receive(:object_term) { object_term }
      allow(helper).to receive(:toggle_id).with(predicate, object_term, nil) { toggle_id }
    end

    I18n.available_locales.each do |locale|
      context "when locale is #{locale}" do
        let(:locale) { locale }

        it do
          expect(sentences.freshwater.value).to eq(I18n.t(
            'brief_summary.freshwater_html',
            class_str: BriefSummary::TermTagger.tag_class_str,
            id: toggle_id,
            locale: locale
          ))
        end

        context "when page isn't genus_or_below?" do
          before { allow(page).to receive(:genus_or_below?) { false } }

          it { expect(sentences.freshwater).to_not be_valid }
        end
      end
    end

    context "when page isn't freshwater?" do
      let(:locale) { :en }

      before { allow(page).to receive(:freshwater?) { false } }
      
      it { expect(sentences.freshwater).to_not be_valid }
    end
  end

  describe '#fix_nitrogen' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:object) { instance_double('TermNode') }

    before do
      allow(term_node).to receive(:find_by_alias).with('fixes') { predicate }
      allow(term_node).to receive(:find_by_alias).with('nitrogen') { object }
    end

    context 'when page has a fixes/nitrogen trait' do
      let(:trait) { instance_double('Trait') }
      let(:predicate_id) { 'predicate-id' }
      let(:object_id) { 'object-id' }
    
      before do
        allow(page).to receive(:first_trait_for_predicate).with(predicate, for_object_term: object) { trait }
        allow(helper).to receive(:toggle_id).with(nil, predicate, nil) { predicate_id }
        allow(helper).to receive(:toggle_id).with(predicate, object, nil) { object_id }
      end

      I18n.available_locales.each do |locale|
        context "when locale is #{locale}" do
          let(:locale) { locale }

          it do 
            expect(sentences.fix_nitrogen.value).to eq(I18n.t(
              'brief_summary.fix_nitrogen_html',
              predicate_id: predicate_id,
              object_id: object_id,
              class_str: BriefSummary::TermTagger.tag_class_str,
              locale: locale
            )) 
          end
        end
      end
    end

    context "when page doesn't have a fixes/nitrogen trait" do
      let(:locale) { :en }

      before do
        allow(page).to receive(:first_trait_for_predicate).with(predicate, for_object_term: object) { nil }
      end

      it { expect(sentences.fix_nitrogen).to_not be_valid }
    end
  end
end

