require 'rails_helper'

RankTestCase = Struct.new(:treat_as, :expected)

RSpec.describe('BriefSummary::PageDecorator') do
  let(:page) { instance_double('Page') }
  let(:view) { double('view_helper') }
  let(:rank) { instance_double('Rank') }

  before do
    allow(page).to receive(:rank) { rank }
  end

  subject(:decorator) { BriefSummary::PageDecorator.new(page, view) }

  describe '#rank' do
    it { expect(decorator.rank).to eq(rank) }
  end

  describe '#rank_name' do  
    let(:name) { 'species' }

    before do 
      allow(rank).to receive(:human_treat_as) { name }
    end

    it { expect(decorator.rank_name).to eq(name) }
  end

  shared_examples 'rank method' do |test_cases|
    test_cases.each do |test_case|
      context "when rank is #{test_case.treat_as}" do
        before { allow(rank).to receive(:treat_as) { test_case.treat_as } }

        it { expect(decorator.send(test_method)).to eq(test_case.expected) }
      end
    end
  end

  describe '#family_or_above?' do
    let(:test_method) { :family_or_above? }

    it_behaves_like 'rank method', [
      RankTestCase.new(:r_family, true),
      RankTestCase.new(:r_kingdom, true),
      RankTestCase.new(:r_species, false)
    ]
  end

  describe '#below_family?' do
    let(:test_method) { :below_family? }

    it_behaves_like 'rank method', [
      RankTestCase.new(:r_family, false),
      RankTestCase.new(:r_kingdom, false),
      RankTestCase.new(:r_species, true)
    ]
  end

  describe '#above_family?' do
    let(:test_method) { :above_family? }

    it_behaves_like 'rank method', [
      RankTestCase.new(:r_family, false),
      RankTestCase.new(:r_kingdom, true),
      RankTestCase.new(:r_species, false)
    ]
  end

  describe '#genus_or_below?' do
    let(:test_method) { :genus_or_below? }

    it_behaves_like 'rank method', [
      RankTestCase.new(:r_family, false),
      RankTestCase.new(:r_genus, true),
      RankTestCase.new(:r_species, true)
    ]
  end

  describe '#traits_for_predicate' do
    let(:predicate) { instance_double('TermNode') }
    let(:traits) { instance_double('Array') }

    before { allow(page).to receive(:traits_for_predicate).with(predicate, exclude_hidden_from_overview: true) { traits } }

    it { expect(decorator.traits_for_predicate(predicate)).to eq(traits) }
  end

  def setup_native_range_traits(traits)
    term_node = class_double('TermNode').as_stubbed_const
    predicate = instance_double('TermNode')

    allow(term_node).to receive(:find_by_alias).with('native_range') { predicate }
    allow(page).to receive(:traits_for_predicate).with(predicate, exclude_hidden_from_overview: true) { traits }
  end

  describe '#native_range_traits' do
    let(:traits) { instance_double('Array') }

    before { setup_native_range_traits(traits) }
    
    it { expect(decorator.native_range_traits).to eq(traits) }
  end

  describe '#has_native_range?' do
    let(:traits) { instance_double('Array') }

    context 'when page has native_range traits' do
      before do
        allow(traits).to receive(:any?) { true }
        setup_native_range_traits(traits)
      end

      it { expect(decorator.has_native_range?).to eq(true) }
    end

    context 'when page has no native_range traits' do
      before do
        allow(traits).to receive(:any?) { false }
        setup_native_range_traits(traits)
      end

      it { expect(decorator.has_native_range?).to eq(false) }
    end
  end

  describe '#a1' do
    let(:ancestors) { (0..3).map { |_| instance_double('Node') } }

    before do 
      ancestors.each { |a| allow(a).to receive(:minimal?) { false }
      allow(page).to receive(:ancestors) { ancestors } }
    end

    context 'when page has no minimal? ancestor' do
      it { expect(decorator.a1).to eq(nil) }
    end

    context 'when page has minimal? ancestors' do
      let(:target_ancestor) { ancestors[2] } 

      before do
        allow(ancestors.first).to receive(:minimal?) { true }
        allow(target_ancestor).to receive(:minimal?) { true }
      end

      context 'when target_ancestor.page is present' do
        let(:page) { instance_double('Page') }
        let(:link) { '<link_to_page>' }
        let(:name) { '<name>' }

        before do
          allow(target_ancestor).to receive(:page) { page }
          allow(view).to receive(:link_to).with(name, page) { link }
        end

        context 'when page.vernacular.string is present' do
          let(:vernacular) { instance_double('Vernacular') }

          before do
            allow(page).to receive(:vernacular) { vernacular }
            allow(vernacular).to receive(:string) { name }
          end

          it { expect(decorator.a1).to eq(link) }
        end

        context 'when page.vernacular.string is not present' do
          context 'when target_ancestor.vernacular is not present' do
            let(:name) { '<canonical>' }

            before do
              allow(page).to receive(:vernacular) { nil }
              allow(target_ancestor).to receive(:vernacular) { nil }
              allow(target_ancestor).to receive(:canonical) { name }
            end

            it { expect(decorator.a1).to eq(link) }
          end
        end

        context 'when vernacular contains "and"' do
          let(:vernacular) { instance_double('Vernacular') }
          let(:vernacular_string) { 'wasps and bees' }
          let(:name) { '<canonical>' }

          before do
            allow(page).to receive(:vernacular) { vernacular }
            allow(vernacular).to receive(:string) { vernacular_string }
            allow(target_ancestor).to receive(:canonical) { name }
          end

          it { expect(decorator.a1).to eq(link) }
        end
      end

      context 'when target_ancestor.page is not present' do
        before do
          allow(target_ancestor).to receive(:page) { nil }
        end

        context 'when vernacular is present' do
          context 'when vernacular does not contain "and"' do 
            let(:name) { '<vernacular>' }

            before { allow(target_ancestor).to receive(:vernacular) { name } }

            it { expect(decorator.a1).to eq(name) }
          end

          context 'when vernacular contains "and"' do 
            let(:vernacular) { 'wasps and bees' }
            let(:canonical) { '<canonical>' }

            before do 
              allow(target_ancestor).to receive(:vernacular) { vernacular }
              allow(target_ancestor).to receive(:canonical) { canonical }
            end

            it { expect(decorator.a1).to eq(canonical) }
          end
        end

        context 'when vernacular is not present' do
          let(:canonical) { '<canonical>' }

          before do
            allow(target_ancestor).to receive(:canonical) { canonical }
            allow(target_ancestor).to receive(:vernacular) { nil }
          end

          it { expect(decorator.a1).to eq(canonical) }
        end
      end
    end
  end

  describe '#a2' do
    let(:ancestors) { (0..3).map { |_| instance_double('Node') } }

    before do
      ancestors.each { |a| allow(a).to receive(:rank_id) { 3 } }
      allow(page).to receive(:ancestors) { ancestors }
      allow(Rank).to receive(:family_ids) { [1, 2] }
    end

    context 'when page has a family ancestor' do
      let(:target_ancestor) { ancestors[2] }

      before do
        allow(ancestors.first).to receive(:rank_id) { 1 }
        allow(target_ancestor).to receive(:rank_id) { 2 }
      end

      context 'when target_ancestor.page is present' do
        shared_examples 'vernacular present' do |method|
          let(:link) { '<link>' }

          context "when it doesn't contain restricted words" do
            let(:string) { '<vernacular>' }

            before do 
              allow(receiver).to receive(method) { string }
              allow(view).to receive(:link_to).with(string, anc_page) { link }
            end

            it { expect(decorator.a2).to eq(link) }
          end

          context 'when it contains a restricted word' do
            shared_examples 'restricted word' do
              let(:canonical) { '<canonical>' }

              before do 
                allow(receiver).to receive(method) { string }
                allow(target_ancestor).to receive(:canonical) { canonical }
                allow(view).to receive(:link_to).with(canonical, anc_page) { link }
              end

              it { expect(decorator.a2).to eq(link) }
            end

            context "when it contains 'and'" do
              let(:string) { 'fluffy and cute' }

              it_behaves_like 'restricted word'
            end

            context "when it contains 'family'" do
              let(:string) { 'rodent family' }

              it_behaves_like 'restricted word'
            end
          end
        end

        let(:anc_page) { instance_double('Page') }

        before { allow(target_ancestor).to receive(:page) { anc_page } }

        context 'when anc_page.vernacular.string is present' do
          let(:vernacular) { instance_double('Vernacular') }
          let(:receiver) { vernacular }

          before do
            allow(anc_page).to receive(:vernacular) { vernacular }
          end

          it_behaves_like 'vernacular present', :string
        end

        context 'when target_ancestor.vernacular is present' do
          let(:receiver) { target_ancestor }

          before { allow(anc_page).to receive(:vernacular) { nil } }

          it_behaves_like 'vernacular present', :vernacular
        end
      end

      context 'when target_ancestor.page is not present' do
        before { allow(target_ancestor).to receive(:page) { nil } }

        context 'when target_ancestor.vernacular is present' do
          before { allow(target_ancestor).to receive(:vernacular) { vernacular } }

          context "when it doesn't contain restricted words" do
            let(:vernacular) { '<vernacular>' }

            it { expect(decorator.a2).to eq(vernacular) }
          end

          shared_examples 'restricted word' do
            let(:canonical) { '<canonical>' }

            before { allow(target_ancestor).to receive(:canonical) { canonical } }

            it { expect(decorator.a2).to eq(canonical) }
          end

          context "when it contains 'family'" do
            let(:vernacular) { 'rodent family' }

            it_behaves_like 'restricted word'
          end

          context "when it contains 'and'" do
            let(:vernacular) { 'fluffy and cute' }

            it_behaves_like 'restricted word'
          end
        end
      end
    end

    context 'when page has no family ancestor' do
      it { expect(decorator.a2).to be_nil }
    end
  end

  describe '#full_name' do
    before { allow(page).to receive(:canonical) { 'Canonical' } }

    context 'when page.vernacular is present' do
      let(:vernacular) { instance_double('Vernacular') }

      before do
        allow(page).to receive(:vernacular) { vernacular }
        allow(vernacular).to receive(:string) { 'vernacular name' }
      end

      it { expect(decorator.full_name).to eq('Canonical (Vernacular Name)') }
    end

    context 'when page.vernacular is not present' do
      before { allow(page).to receive(:vernacular) { nil } }

      it { expect(decorator.full_name).to eq('Canonical') }
    end
  end

  describe '#name' do
    let(:name) { '<page name>' }

    before { allow(page).to receive(:vernacular_or_canonical) { name } }

    it { expect(decorator.name).to eq(name) }
  end

  describe '#desc_info' do
    let(:desc_info) { instance_double('Page::DescInfo') }
    
    before { allow(page).to receive(:desc_info) { desc_info } }

    it { expect(decorator.desc_info).to eq(desc_info) }
  end

  describe '#growth_habit_matches' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:traits) { instance_double('Array') }
    let(:growth_habit_group) { class_double('BriefSummary::GrowthHabitGroup').as_stubbed_const }
    let(:matches) { instance_double('Array') }

    before do
      allow(term_node).to receive(:find_by_alias).with('growth_habit') { predicate }
      allow(page).to receive(:traits_for_predicate).with(predicate) { traits }
      allow(growth_habit_group).to receive(:match_all).with(traits) { matches }
    end

    it { expect(decorator.growth_habit_matches).to eq(matches) }
  end

  describe '#extinct?' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:extinct_obj) { instance_double('TermNode') }
    let(:extant_obj) { instance_double('TermNode') }
    let(:extinct_trait) { instance_double('Trait') } 
    let(:extant_trait) { instance_double('Trait') } 

    before do
      allow(term_node).to receive(:find_by_alias).with('iucn_ex') { extinct_obj }
      allow(term_node).to receive(:find_by_alias).with('extant') { extant_obj }
    end

    context 'when extinct trait is present' do
      before do
        allow(page).to receive(:first_trait_for_object_terms).with([extinct_obj]) { extinct_trait }
      end

      context 'when extant trait is present' do
        before do
          allow(page).to receive(:first_trait_for_object_terms)
            .with([extant_obj], match_object_descendants: true) { extant_trait }
        end

        it { expect(decorator.extinct?).to eq(false) }
      end

      context 'when extant trait is not present' do
        before do
          allow(page).to receive(:first_trait_for_object_terms).with([extant_obj], match_object_descendants: true) { nil }
        end

        it { expect(decorator.extinct?).to eq(true) }
      end
    end

    context 'when extinct trait is not present' do
      before do
        allow(page).to receive(:first_trait_for_object_terms).with([extinct_obj]) { nil }
      end

      it { expect(decorator.extinct?).to eq(false) }
    end
  end

  describe '#marine?/freshwater?' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:marine_obj) { instance_double('TermNode') }
    let(:terrestrial_obj) { instance_double('TermNode') }
    let(:marine_trait) { instance_double('Trait') }
    let(:terrestrial_trait) { instance_double('Trait') }

    def setup_marine(val)
      allow(page).to receive(:has_data_for_predicate).with(predicate, with_object_term: marine_obj) { val }
    end

    def setup_terrestrial(val)
      allow(page).to receive(:has_data_for_predicate).with(predicate, with_object_term: terrestrial_obj) { val }
    end

    before do
      allow(term_node).to receive(:find_by_alias).with('habitat') { predicate }
      allow(term_node).to receive(:find_by_alias).with('marine') { marine_obj }
      allow(term_node).to receive(:find_by_alias).with('terrestrial') { terrestrial_obj }
    end

    describe '#marine?' do
      context 'when page has marine data' do
        before { setup_marine(true) }

        context "when page doesn't have terrestrial data" do
          before { setup_terrestrial(false) }

          it { expect(decorator.marine?).to eq(true) }
        end

        context 'when page has terrestrial data' do
          before { setup_terrestrial(true) }

          it { expect(decorator.marine?).to eq(false) }
        end
      end

      context "when page doesn't have marine data" do
        before { setup_marine(false) }
        
        it { expect(decorator.marine?).to eq(false) }
      end
    end

    describe '#freshwater?' do
      let(:freshwater_obj) { instance_double('TermNode') }

      before do
        allow(term_node).to receive(:find_by_alias).with('freshwater') { freshwater_obj }
      end

      def set_freshwater_trait(trait)
        allow(page).to receive(:first_trait_for_object_terms).with([freshwater_obj]) { trait }
      end

      context 'when page has a freshwater trait' do
        let(:trait) { instance_double('Trait') }

        before { set_freshwater_trait(trait) }

        context 'when marine?' do
          before do
            setup_marine(true)
            setup_terrestrial(false)
          end

          it { expect(decorator.freshwater?).to eq(false) } 
        end

        context 'when not marine?' do
          before do
            setup_marine(false)
          end

          it { expect(decorator.freshwater?).to eq(true) } 
        end
      end

      context "when page doesn't have a freshwater trait" do
        before { set_freshwater_trait(nil) }

        it { expect(decorator.freshwater?).to eq(false) }
      end
    end
  end

  describe '#landmark_children' do
    context 'when page.native_node is present' do
      def build_child(has_page)
        child_node = instance_double('Node')
        page = has_page ? instance_double('Page') : nil

        allow(child_node).to receive(:page) { page }

        child_node
      end

      let(:node) { instance_double('Node') }
      let(:child1) { build_child(true) }
      let(:child2) { build_child(true) }

      let(:children) do
        [
          child1,
          child2,
          build_child(false)
        ]
      end

      before do 
        allow(page).to receive(:native_node) { node }
        allow(node).to receive(:landmark_children) { children }
      end

      it { expect(decorator.landmark_children).to eq([child1.page, child2.page]) }
    end

    context 'when page.native_node is not present' do
      before { allow(page).to receive(:native_node) { nil } }

      it { expect(decorator.landmark_children).to eq([]) }
    end
  end

  describe '#greatest_value_size_trait' do
    def build_trait(measurement, units)
      trait = instance_double('Trait')
      allow(trait).to receive(:normal_measurement) { measurement }
      allow(trait).to receive(:units_term) { units }

      trait
    end

    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:body_mass) { instance_double('TermNode') }
    let(:body_length) { instance_double('TermNode') }
    let(:units) { instance_double('TermNode') }
    let(:target_trait) { build_trait(20, units) }

    let(:traits) do
      [
        build_trait(14.5, units),
        target_trait,
        build_trait(nil, units),
        build_trait(20000, nil)
      ]
    end

    let(:all_invalid_traits) do
      [
        build_trait(nil, units),
        build_trait(20, nil)
      ]
    end

    before do
      allow(term_node).to receive(:find_by_alias).with('body_mass') { body_mass }
      allow(term_node).to receive(:find_by_alias).with('body_length') { body_length }
    end

    shared_examples 'has traits' do
      context 'when there are valid traits' do
        before { allow(page).to receive(:traits_for_predicate).with(predicate, includes: [:units_term]) { traits } } 

        it { expect(decorator.greatest_value_size_trait).to eq(target_trait) }
      end

      context 'when none are valid' do
        before { allow(page).to receive(:traits_for_predicate).with(predicate, includes: [:units_term]) { all_invalid_traits } }

        it { expect(decorator.greatest_value_size_trait).to eq(nil) }
      end
    end

    context 'when page has body_mass traits' do
      let(:predicate) { body_mass }

      it_behaves_like 'has traits'
    end

    context "when page doesn't have body_mass traits" do
      before { allow(page).to receive(:traits_for_predicate).with(body_mass, includes: [:units_term]) { [] } }

      context 'when page has body_length traits' do
        let(:predicate) { body_length }

        it_behaves_like 'has traits'
      end

      context "when page doesn't have body_length traits" do
        before { allow(page).to receive(:traits_for_predicate).with(body_length, includes: [:units_term]) { [] } }
        
        it { expect(decorator.greatest_value_size_trait).to eq(nil) }
      end
    end
  end

  describe '#leaf_traits' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:complexity) { instance_double('TermNode') }
    let(:morphology) { instance_double('TermNode') }
    let(:complexity_trait) { instance_double('Trait') }
    let(:morphology_trait) { instance_double('Trait') }

    before do
      allow(term_node).to receive(:find_by_alias).with('leaf_complexity') { complexity }
      allow(term_node).to receive(:find_by_alias).with('leaf_morphology') { morphology }
    end

    def set_trait_for_predicate(predicate, trait)
      allow(page).to receive(:first_trait_for_predicate)
        .with(predicate, exclude_hidden_from_overview: true, exact_predicate: true) { trait }
    end

    context 'when page has traits for both predicates' do
      before do
        set_trait_for_predicate(complexity, complexity_trait)
        set_trait_for_predicate(morphology, morphology_trait)
      end

      it { expect(decorator.leaf_traits).to eq([complexity_trait, morphology_trait]) }
    end

    context 'when page has a leaf_complexity trait' do
      before do
        set_trait_for_predicate(complexity, complexity_trait)
        set_trait_for_predicate(morphology, nil)
      end

      it { expect(decorator.leaf_traits).to eq([complexity_trait]) }
    end

    context 'when page has a leaf_morphology trait' do
      before do
        set_trait_for_predicate(complexity, nil)
        set_trait_for_predicate(morphology, morphology_trait)
      end

      it { expect(decorator.leaf_traits).to eq([morphology_trait]) }
    end

    context "when page doesn't have a trait for either predicate" do
      before do
        set_trait_for_predicate(complexity, nil)
        set_trait_for_predicate(morphology, nil)
      end

      it { expect(decorator.leaf_traits).to eq([]) }
    end
  end

  describe '#form_trait1/form_trait2' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:lifestage) { instance_double('TermNode') }
    let(:lifestage_name) { '<lifestage name>' }

    before do
      allow(term_node).to receive(:find_by_alias).with('forms') { predicate }
      allow(lifestage).to receive(:name) { lifestage_name }
      allow(page).to receive(:traits_for_predicate).with(
        predicate,
        exact_predicate: true,
        exclude_hidden_from_overview: true,
        includes: [:predicate, :object_term, :lifestage_term]
      ) { traits }
    end

    def build_trait(obj_uri, lifestage)
      trait = instance_double('Trait')
      obj = instance_double('TermNode')

      allow(trait).to receive(:lifestage_term) { lifestage }
      allow(trait).to receive(:object_term) { obj }
      allow(obj).to receive(:uri) { obj_uri }

      trait
    end

    context 'when there are lifestage and non-lifestage traits' do
      let(:trait1) { build_trait('obj1', lifestage) }
      let(:trait2) { build_trait('obj2', nil) }

      let(:traits) do
        [
          trait1,
          build_trait('obj1', nil),
          trait2
        ]
      end

      it { expect(decorator.form_trait1).to eq(trait1) }
      it { expect(decorator.form_trait2).to eq(trait2) }
    end

    context 'when there are multiple lifestage traits' do
      let(:trait1) { build_trait('obj1', lifestage) }
      let(:trait2) { build_trait('obj2', lifestage) }
      let(:traits) do
        [
          trait1,
          trait1,
          trait2,
          trait2
        ]
      end

      it { expect(decorator.form_trait1).to eq(trait1) }
      it { expect(decorator.form_trait2).to eq(trait2) }
    end

    context 'when there is a single distinct lifestage trait' do
      let(:trait) { build_trait('obj', lifestage) }
      let(:traits) do
        [
          trait,
          trait
        ]
      end

      it { expect(decorator.form_trait1).to eq(trait) }
      it { expect(decorator.form_trait2).to eq(nil) }
    end

    context 'when there are multiple non-lifestage traits' do
      let(:trait1) { build_trait('obj1', nil) }
      let(:trait2) { build_trait('obj2', nil) }
      let(:traits) do
        [
          trait1,
          trait1,
          trait2,
          trait2
        ]
      end

      it { expect(decorator.form_trait1).to eq(trait1) }
      it { expect(decorator.form_trait2).to eq(trait2) }
    end

    context 'when there is a single distinct non-lifestage trait' do
      let(:trait) { build_trait('obj', nil) }

      let(:traits) do
        [
          trait,
          trait
        ]
      end

      it { expect(decorator.form_trait1).to eq(trait) }
      it { expect(decorator.form_trait2).to eq(nil) }
    end

    context 'when there are no traits' do
      let(:traits) { [] }

      it { expect(decorator.form_trait1).to eq(nil) }
      it { expect(decorator.form_trait2).to eq(nil) }
    end
  end

  describe '#reproduction_matches' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:matcher) { class_double('BriefSummary::ReproductionGroupMatcher').as_stubbed_const }
    let(:traits) { instance_double('Array') }
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }

    before do
      allow(term_node).to receive(:find_by_alias).with('reproduction') { predicate }
      allow(page).to receive(:traits_for_predicate).with(predicate, exclude_hidden_from_overview: true) { traits }
      allow(matcher).to receive(:match_all).with(traits) { matches }
    end

    it { expect(decorator.reproduction_matches).to eq(matches) }
  end

  describe '#motility_matches' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:motility) { instance_double('TermNode') }
    let(:locomotion) { instance_double('TermNode') }
    let(:matcher) { class_double('BriefSummary::MotilityGroupMatcher').as_stubbed_const }
    let(:traits) { instance_double('Array') }
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }

    before do
      allow(term_node).to receive(:find_by_alias).with('motility') { motility }
      allow(term_node).to receive(:find_by_alias).with('locomotion') { locomotion }
      allow(page).to receive(:traits_for_predicates).with([motility, locomotion]) { traits }
      allow(matcher).to receive(:match_all).with(traits) { matches }
    end

    it { expect(decorator.motility_matches).to eq(matches) }
  end

  describe '#animal?' do
    context 'when page.animal?' do
      before { allow(page).to receive(:animal?) { true } }

      it { expect(decorator.animal?).to eq(true) }
    end

    context 'when not page.animal?' do
      before { allow(page).to receive(:animal?) { false } }

      it { expect(decorator.animal?).to eq(false) }
    end
  end
end

