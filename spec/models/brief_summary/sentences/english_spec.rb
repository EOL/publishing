require 'rails_helper'
require 'brief_summary/page_decorator'
require 'brief_summary/sentences/helper'
require 'brief_summary/obj_uri_group_matcher'
require 'trait'

RSpec.describe('BriefSummary::Sentences::English') do
  let(:page) { instance_double('BriefSummary::PageDecorator') }
  let(:helper) { instance_double('BriefSummary::Sentences::Helper') }
  let(:page_name) { 'Page (page)' }
  let(:page_rank) { 'page_rank' }
  let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }
  let(:match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
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
        let(:species) { 20 }
        let(:genera) { 5 }
        let(:families) { 2 }
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
          let(:expected) { "There are 0 species of <page>, in 5 #{genus_part} and 2 #{family_part}." }

          it_behaves_like 'valid input'
        end

        context 'when species_count == 1' do
          let(:species) { 1 }
          let(:expected) { "There is 1 species of <page>, in 5 #{genus_part} and 2 #{family_part}." }

          it_behaves_like 'valid input'
        end

        context 'when species_count > 1' do
          let(:species) { 20 }
          let(:expected) { "There are 20 species of <page>, in 5 #{genus_part} and 2 #{family_part}." }

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

  describe '#conservation' do
    let(:conservation_class) { class_double('BriefSummary::ConservationStatus').as_stubbed_const }
    let(:conservation_instance) { instance_double('BriefSummary::ConservationStatus') }
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:by_provider) { {} }

    before do 
      allow(term_node).to receive(:find_by_alias).with('conservation_status') { predicate }
      allow(page).to receive(:genus_or_below?) { true }
    end

    def add_provider(provider, fstr, fmt_result)
      trait = instance_double('Trait')
      source = "#{provider}_source"
      object_term = instance_double('TermNode')
      object_name = "#{provider}_obj_term_name"

      allow(object_term).to receive(:name) { object_name }
      allow(trait).to receive(:object_term) { object_term }
      allow(trait).to receive(:source) { source }

      allow(helper).to receive(:add_term_to_fmt).with(
        fstr, 
        object_name,
        predicate,
        object_term,
        source
      ) { fmt_result }

      by_provider[provider] = trait
    end

    def add_iucn
      add_provider(:iucn, 'as %s by IUCN', 'as <iucn_val> by IUCN')
    end

    def add_cosewic
      add_provider(:cosewic, 'as %s by COSEWIC', 'as <cosewic_val> by COSEWIC')
    end

    def add_usfw
      add_provider(:usfw, 'as %s by the US Fish and Wildlife Service', 'as <usfw_val> by the US Fish and Wildlife Service')
    end

    def add_cites
      add_provider(:cites, 'in %s', 'in <cites_val>')
    end

    before do
      allow(conservation_class).to receive(:new).with(page) { conservation_instance }
      allow(conservation_instance).to receive(:by_provider) { by_provider }
    end

    context 'when there are no providers' do 
      it { expect(sentences.conservation).to_not be_valid }
    end

    shared_examples 'provider present' do
      it { expect(sentences.conservation.value).to eq(expected) }

      context 'when page is not genus_or_below?' do
        before { allow(page).to receive(:genus_or_below?) { false } }
        it { expect(sentences.conservation).to_not be_valid }
      end
    end

    context 'when :iucn is present' do
      before { add_iucn }
      let(:expected) { 'They are listed as <iucn_val> by IUCN.' }
      
      it_behaves_like 'provider present'
    end

    context 'when :cosewic is present' do
      before { add_cosewic }
      let(:expected) { 'They are listed as <cosewic_val> by COSEWIC.' }

      it_behaves_like 'provider present'
    end

    context 'when :usfw is present' do
      before { add_usfw }
      let(:expected) { 'They are listed as <usfw_val> by the US Fish and Wildlife Service.' }
    end

    context 'when :cites is present' do
      before { add_cites }
      let(:expected) { 'They are listed in <cites_val>.' }

      it_behaves_like 'provider present'
    end

    context 'when all providers are present' do
      before do
        add_iucn
        add_cosewic
        add_usfw
        add_cites
      end

      let(:expected) { 'They are listed as <iucn_val> by IUCN, as <cosewic_val> by COSEWIC, as <usfw_val> by the US Fish and Wildlife Service, and in <cites_val>.' }

      it_behaves_like 'provider present'
    end

    context 'when a subset of providers is present' do
      before do
        add_cosewic
        add_cites
      end

      let(:expected) { 'They are listed as <cosewic_val> by COSEWIC and in <cites_val>.' }

      it_behaves_like 'provider present'
    end
  end

  describe '#native_range' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:traits) { instance_double('Array') }

    before do
      allow(page).to receive(:genus_or_below?) { true }
      allow(page).to receive(:has_native_range?) { true }
      allow(page).to receive(:native_range_traits) { traits }
      allow(term_node).to receive(:find_by_alias).with('native_range') { predicate }
      allow(helper).to receive(:trait_vals_to_sentence).with(traits, predicate) { 'North America and Europe' }
    end

    it { expect(sentences.native_range.value).to eq('They are native to North America and Europe.') }

    context 'when not page.has_native_range?' do
      before { allow(page).to receive(:has_native_range?) { false } }

      it { expect(sentences.native_range).to_not be_valid }
    end
        
    context 'when page is not genus_or_below?' do
      before { allow(page).to receive(:genus_or_below?) { false } }

      it { expect(sentences.native_range).to_not be_valid }
    end
  end

  describe '#found_in' do
    before do
      allow(page).to receive(:g1) { '<g1>' }
      allow(page).to receive(:has_native_range?) { false }
      allow(page).to receive(:genus_or_below?) { true }
    end

    it { expect(sentences.found_in.value).to eq('They are found in <g1>.') }

    context 'when page.has_native_range?' do
      before { allow(page).to receive(:has_native_range?) { true }

      it { expect(sentences.found_in).not_to be_valid } }
    end

    context 'when page is not genus_or_below?' do
      before { allow(page).to receive(:genus_or_below?) { false } }
      it { expect(sentences.found_in).not_to be_valid }
    end

    context 'when page.g1 is nil' do
      before { allow(page).to receive(:g1) { nil } }

      it { expect(sentences.found_in).not_to be_valid }
    end
  end

  describe '#landmark_children' do
    let(:child2) { instance_double('Page') }
    let(:child2) { instance_double('Page') }
    let(:child3) { instance_double('Page') }
    let(:link2) { 'link2' }
    let(:link2) { 'link2' }
    let(:link3) { 'link3' }
    let(:children) { [child2, child2, child3] }
    
    before do
      allow(page).to receive(:landmark_children) { children }
      allow(helper).to receive(:page_link).with(child2) { link2 }
      allow(helper).to receive(:page_link).with(child2) { link2 }
      allow(helper).to receive(:page_link).with(child3) { link3 }
    end

    it { expect(sentences.landmark_children.value).to eq('It includes groups like link2, link2, and link3.') }

    context 'when page.landmark_children.empty?' do
      before { allow(page).to receive(:landmark_children) { [] } }

      it { expect(sentences.landmark_children).to_not be_valid }
    end
  end

  describe '#behavior' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:nocturnal) { instance_double('TermNode') }
    let(:diurnal) { instance_double('TermNode') }
    let(:crepuscular) { instance_double('TermNode') }
    let(:trophic_level) { instance_double('TermNode') }
    let(:variable) { instance_double('TermNode') }
    let(:solitary) { instance_double('TermNode') }
    let(:circadian_trait) { instance_double('Trait') }
    let(:solitary_trait) { instance_double('Trait') }
    let(:trophic_trait) { instance_double('Trait') }

    before do
      allow(term_node).to receive(:find_by_alias).with('nocturnal') { nocturnal }
      allow(term_node).to receive(:find_by_alias).with('diurnal') { diurnal }
      allow(term_node).to receive(:find_by_alias).with('crepuscular') { crepuscular }
      allow(term_node).to receive(:find_by_alias).with('trophic_level') { trophic_level }
      allow(term_node).to receive(:find_by_alias).with('variable') { variable }
      allow(term_node).to receive(:find_by_alias).with('solitary') { solitary }
    end

    context 'when all trait types are present' do
      before do 
        allow(page).to receive(:first_trait_for_object_terms).with([nocturnal, diurnal, crepuscular]) { circadian_trait }
        allow(page).to receive(:first_trait_for_object_term).with(solitary) { solitary_trait }
        allow(page).to receive(:first_trait_for_predicate).with(trophic_level, exclude_values: [variable]) { trophic_trait }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trophic_trait, pluralize: true) { '<trophic value>s' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', circadian_trait) { '<circadian value>' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', solitary_trait) { '<solitary value>' }
      end

      it { expect(sentences.behavior.value).to eq('They are <solitary value>, <circadian value> <trophic value>s.') }
    end

    context 'when circadian and trophic traits are present' do
      before do 
        allow(page).to receive(:first_trait_for_object_terms).with([nocturnal, diurnal, crepuscular]) { circadian_trait }
        allow(page).to receive(:first_trait_for_object_term).with(solitary) { nil }
        allow(page).to receive(:first_trait_for_predicate).with(trophic_level, exclude_values: [variable]) { trophic_trait }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trophic_trait, pluralize: true) { '<trophic value>s' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', circadian_trait) { '<circadian value>' }
      end

      it { expect(sentences.behavior.value).to eq('They are <circadian value> <trophic value>s.') }
    end

    context 'when circadian and trophic traits are present' do
      before do 
        allow(page).to receive(:first_trait_for_object_terms).with([nocturnal, diurnal, crepuscular]) { circadian_trait }
        allow(page).to receive(:first_trait_for_object_term).with(solitary) { nil }
        allow(page).to receive(:first_trait_for_predicate).with(trophic_level, exclude_values: [variable]) { trophic_trait }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trophic_trait, pluralize: true) { '<trophic value>s' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', circadian_trait) { '<circadian value>' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', solitary_trait) { '<solitary value>' }
      end

      it { expect(sentences.behavior.value).to eq('They are <circadian value> <trophic value>s.') }
    end

    context 'when solitary and trophic traits are present' do
      before do 
        allow(page).to receive(:first_trait_for_object_terms).with([nocturnal, diurnal, crepuscular]) { nil }
        allow(page).to receive(:first_trait_for_object_term).with(solitary) { solitary_trait }
        allow(page).to receive(:first_trait_for_predicate).with(trophic_level, exclude_values: [variable]) { trophic_trait }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trophic_trait, pluralize: true) { '<trophic value>s' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', solitary_trait) { '<solitary value>' }
      end

      it { expect(sentences.behavior.value).to eq('They are <solitary value> <trophic value>s.') }
    end

    context 'when trophic trait is present' do
      before do 
        allow(page).to receive(:first_trait_for_object_terms).with([nocturnal, diurnal, crepuscular]) { nil }
        allow(page).to receive(:first_trait_for_object_term).with(solitary) { nil }
        allow(page).to receive(:first_trait_for_predicate).with(trophic_level, exclude_values: [variable]) { trophic_trait }
        allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trophic_trait, pluralize: true) { '<trophic value>s' }
      end

      it { expect(sentences.behavior.value).to eq('They are <trophic value>s.') }
    end

    context 'when no traits are present' do
      before do 
        allow(page).to receive(:first_trait_for_object_terms).with([nocturnal, diurnal, crepuscular]) { nil }
        allow(page).to receive(:first_trait_for_object_term).with(solitary) { nil }
        allow(page).to receive(:first_trait_for_predicate).with(trophic_level, exclude_values: [variable]) { nil }
      end

      it { expect(sentences.behavior).to_not be_valid }
    end
  end

  describe '#size_lifespan' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:lifespan) { instance_double('TermNode') }
    let(:lifespan_measurement) { '<lifespan measurement>' }
    let(:lifespan_units) { instance_double('TermNode') }
    let(:lifespan_units_name) { '<lifespan units>' }
    let(:lifespan_trait) { instance_double('Trait') }
    let(:size_trait) { instance_double('Trait') }
    let(:size_measurement) { '<size measurement>' }
    let(:size_units) { instance_double('TermNode') }
    let(:size_units_name) { '<size units>' }

    before do
      allow(term_node).to receive(:find_by_alias).with('lifespan') { lifespan }
      allow(page).to receive(:greatest_value_size_trait) { nil }
      allow(page).to receive(:first_trait_for_predicate).with(lifespan, includes: [:units_term]) { nil }
      allow(page).to receive(:extinct?) { false }
    end

    def setup_size_trait
      allow(size_trait).to receive(:measurement) { size_measurement }
      allow(size_trait).to receive(:units_term) { size_units }
      allow(size_units).to receive(:name) { size_units_name }
      allow(page).to receive(:greatest_value_size_trait) { size_trait }
    end

    def setup_lifespan_trait
      allow(lifespan_trait).to receive(:measurement) { lifespan_measurement }
      allow(lifespan_trait).to receive(:units_term) { lifespan_units }
      allow(lifespan_units).to receive(:name) { lifespan_units_name }
      allow(page).to receive(:first_trait_for_predicate).with(lifespan, includes: [:units_term]) { lifespan_trait }
    end

    shared_examples 'traits present' do
      context 'when page is not extinct?' do
        before { allow(page).to receive(:extinct?) { false } }

        it { expect(sentences.lifespan_size.value).to eq(expected_normal) }
      end

      context 'when page is extinct?' do
        before { allow(page).to receive(:extinct?) { true } }

        it { expect(sentences.lifespan_size.value).to eq(expected_extinct) }
      end
    end



    context 'when size and lifespan traits are present' do
      let(:expected_normal) { 'Individuals are known to live for <lifespan measurement> <lifespan units> and can grow to <size measurement> <size units>.' }
      let(:expected_extinct) { 'Individuals were known to live for <lifespan measurement> <lifespan units> and could grow to <size measurement> <size units>.' }

      before do
        setup_lifespan_trait
        setup_size_trait
      end

      it_behaves_like 'traits present'
    end

    context 'when size trait is present' do
      let(:expected_normal) { 'Individuals can grow to <size measurement> <size units>.' }
      let(:expected_extinct) { 'Individuals could grow to <size measurement> <size units>.' }

      before { setup_size_trait }

      it_behaves_like 'traits present'
    end

    context 'when lifespan trait is present' do
      let(:expected_normal) { 'Individuals are known to live for <lifespan measurement> <lifespan units>.' }
      let(:expected_extinct) { 'Individuals were known to live for <lifespan measurement> <lifespan units>.' }

      before { setup_lifespan_trait }

      it_behaves_like 'traits present'
    end

    context 'when no traits are present' do
      before { allow(page).to receive(:extinct?) { false } }

      it { expect(sentences.lifespan_size).to_not be_valid }
    end
  end

  describe '#plant_description' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:flower_color) { instance_double('TermNode') }
    let(:flower_color_trait) { instance_double('Trait') }
    let(:fruit_type) { instance_double('TermNode') }
    let(:fruit_type_trait) { instance_double('Trait') }
    let(:leaf_trait1) { instance_double('Trait') }
    let(:leaf_trait2) { instance_double('Trait') }

    before do
      allow(term_node).to receive(:find_by_alias).with('flower_color') { flower_color }
      allow(term_node).to receive(:find_by_alias).with('fruit_type') { fruit_type }
      allow(page).to receive(:first_trait_for_predicate).with(flower_color) { nil }
      allow(page).to receive(:first_trait_for_predicate).with(fruit_type) { nil }
      allow(page).to receive(:leaf_traits) { [] }
      allow(helper).to receive(:add_trait_val_to_fmt).with('%s', leaf_trait1) { '<leaf1>' }
      allow(helper).to receive(:add_trait_val_to_fmt).with('%s', leaf_trait2) { '<leaf2>' }
      allow(helper).to receive(:add_trait_val_to_fmt).with('%s flowers', flower_color_trait) { '<flower color> flowers' }
      allow(helper).to receive(:add_trait_val_to_fmt).with('%s', fruit_type_trait) { '<fruit type>' }
    end

    def setup_leaf_traits(traits)
      allow(page).to receive(:leaf_traits) { traits }
    end

    def setup_flower_trait
      allow(page).to receive(:first_trait_for_predicate).with(flower_color) { flower_color_trait }
    end

    def setup_fruit_trait
      allow(page).to receive(:first_trait_for_predicate).with(fruit_type) { fruit_type_trait }
    end

    context 'when page has two leaf_traits' do
      before { setup_leaf_traits([leaf_trait1, leaf_trait2 ]) }

      it { expect(sentences.plant_description.value).to eq('They have <leaf1>, <leaf2> leaves.') }
    end

    context 'when page has one leaf_trait' do
      before { setup_leaf_traits([leaf_trait1]) }
      
      it { expect(sentences.plant_description.value).to eq('They have <leaf1> leaves.') }
    end

    context 'when page has a flower_color trait' do
      before { setup_flower_trait }

      it { expect(sentences.plant_description.value).to eq('They have <flower color> flowers.') }
    end

    context 'when page has a fruit_type trait' do
      before { setup_fruit_trait }

      it { expect(sentences.plant_description.value).to eq('They have <fruit type>.') }
    end

    context 'when page has all traits' do
      before do
        setup_leaf_traits([leaf_trait1, leaf_trait2])
        setup_flower_trait
        setup_fruit_trait
      end

      it { expect(sentences.plant_description.value).to eq('They have <leaf1>, <leaf2> leaves, <flower color> flowers, and <fruit type>.') }
    end

    context 'when page has no traits' do
      it { expect(sentences.plant_description).to_not be_valid }
    end
  end

  shared_examples 'flower visitors' do |test_method, page_method, type, trait_method, prefix|
    def setup_trait(i, page_method)
      trait = instance_double('Trait')
      page = instance_double('Page')
      name = "<page#{i}>"

      allow(trait).to receive(page_method) { page }
      allow(helper).to receive(:add_obj_page_to_fmt).with('%s', page) { name }

      trait
    end

    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }
    let(:trait1) { setup_trait(1, page_method) }
    let(:trait2) { setup_trait(2, page_method) }
    let(:trait3) { setup_trait(3, page_method) }
    let(:trait4) { setup_trait(4, page_method) }
    let(:trait5) { setup_trait(5, page_method) }

    before do
      allow(term_node).to receive(:find_by_alias).with('visits_flowers_of') { predicate }
    end

    context "when page is the #{type} of visits_flowers_of traits" do
      context 'when there are > 4 unique object_pages' do
        before do
          allow(page).to receive(trait_method).with(predicate) { [trait1, trait2, trait3, trait4, trait5] }
        end

        it { expect(sentences.send(test_method).value).to eq("#{prefix} <page1>, <page2>, <page3>, and <page4>.") }
      end

      context 'when there are < 4 unique object_pages' do
        before do
          allow(page).to receive(trait_method).with(predicate) { [trait1, trait2, trait3] }
        end

        it { expect(sentences.send(test_method).value).to eq("#{prefix} <page1>, <page2>, and <page3>.") }
      end

      context 'when there are duplicate object_pages' do
        before do
          allow(page).to receive(trait_method).with(predicate) { [trait1, trait1, trait2, trait2] }
        end

        it { expect(sentences.send(test_method).value).to eq("#{prefix} <page1> and <page2>.") }
      end
    end

    context "when page is not the #{type} of any visits_flowers_of_traits" do
      before do
        allow(page).to receive(trait_method).with(predicate) { [] }
      end

      it { expect(sentences.send(test_method)).to_not be_valid }
    end
  end

  describe '#visits_flowers' do
    it_behaves_like 'flower visitors', :visits_flowers, :object_page, :subject, :traits_for_predicate, 'They visit flowers of'
  end

  describe '#flowers_visited_by' do
    it_behaves_like 'flower visitors', :flowers_visited_by, :page, :object, :object_traits_for_predicate, 'Flowers are visited by'
  end

  shared_examples 'form' do |test_method, trait_method|
    context 'when trait is present' do
      let(:trait) { instance_double('Trait') }
      let(:predicate) { instance_double('Term') }

      before do
        allow(page).to receive(trait_method) { trait }
        allow(page).to receive(:name) { '<taxa>' }
        allow(trait).to receive(:predicate) { predicate }
        allow(helper).to receive(:add_term_to_fmt).with('%s', 'form', nil, predicate) { '<form>' }
      end

      context('when trait has a lifestage') do
        let(:lifestage) { instance_double('TermNode') }
        let(:lifestage_name) { 'lifestage_name' }
        let(:expected) { '<lifestage> <taxa> <form> <object>s.' }

        before do
          allow(trait).to receive(:lifestage_term) { lifestage }
          allow(lifestage).to receive(:name) { lifestage_name }
          allow(helper).to receive(:add_trait_val_to_fmt).with('Lifestage_name <taxa> <form> %ss.', trait) { expected }
        end

        it { expect(sentences.send(test_method).value).to eq(expected) }
      end

      context("when trait doesn't have a lifestage") do
        let(:expected) { '<taxa> form <object>s.' }

        before do
          allow(trait).to receive(:lifestage_term) { nil }
          allow(helper).to receive(:add_trait_val_to_fmt).with('<taxa> <form> %ss.', trait) { expected }
        end

        it { expect(sentences.send(test_method).value).to eq(expected) }
      end
    end

    context('when trait is nil') do
      before { allow(page).to receive(trait_method) { nil } }

      it { expect(sentences.send(test_method)).to_not be_valid }
    end
  end

  describe '#form1' do
    it_behaves_like 'form', :form1, :form_trait1
  end

  describe '#form2' do
    it_behaves_like 'form', :form2, :form_trait2
  end

  describe '#ecosystem_engineering' do
    let(:term_node) { class_double('TermNode').as_stubbed_const }
    let(:predicate) { instance_double('TermNode') }

    before do
      allow(term_node).to receive(:find_by_alias).with('ecosystem_engineering') { predicate }
    end

    context 'when page has an ecosystem engineering trait' do
      let(:object) { instance_double('TermNode') }
      let(:trait) { instance_double('Trait') }
      let(:expected) { 'They are ecosystem engineers.' }

      before do
        allow(page).to receive(:first_trait_for_predicate).with(predicate) { trait }
        allow(trait).to receive(:predicate) { predicate }
        allow(trait).to receive(:object_term) { object }
        allow(object).to receive(:name) { 'ecosystem engineer' }
        allow(helper).to receive(:add_term_to_fmt).with(
          'They are %s.', 
          'ecosystem engineers', 
          predicate, 
          object
        ) { expected }
      end
        
      it { expect(sentences.ecosystem_engineering.value).to eq(expected) }
    end

    context "when page doesn't have an ecosystem engineering trait" do
      before { allow(page).to receive(:first_trait_for_predicate).with(predicate) { nil } }
      it { expect(sentences.ecosystem_engineering).to_not be_valid }
    end
  end

  describe '#reproduction_vw' do
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }
    before do
      allow(page).to receive(:reproduction_matches) { matches } 
    end

    def build_match(name)
      match = instance_double('BriefSummary::ObjUriGroupMatcher::Match')
      trait = instance_double('Trait')
      allow(match).to receive(:trait) { trait }
      allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trait) { name }
      allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trait, pluralize: true) { name + 's' }

      match
    end

    context 'when v and w type matches are present' do
      let(:v_matches) do
        [
          build_match('v1'),
          build_match('v2'),
          build_match('v3')
        ]
      end

      let(:w_matches) do
        [
          build_match('w1'),
          build_match('w2')
        ]
      end

      before do
        allow(matches).to receive(:has_type?).with(:v) { true }
        allow(matches).to receive(:has_type?).with(:w) { true }
        allow(matches).to receive(:by_type).with(:v) { v_matches }
        allow(matches).to receive(:by_type).with(:w) { w_matches }
      end

      it { expect(sentences.reproduction_vw.value).to eq('They have v1, v2, and v3; they are w1s and w2s.') }
    end

    context 'when v-type matches are present' do
      let(:v_matches) { [build_match('v1'), build_match('v2')] }

      before do
        allow(matches).to receive(:has_type?).with(:v) { true }
        allow(matches).to receive(:has_type?).with(:w) { false }
        allow(matches).to receive(:by_type).with(:v) { v_matches }
      end
                        
      it { expect(sentences.reproduction_vw.value).to eq('They have v1 and v2.') }
    end

    context 'when w-type matches are present' do
      let(:w_matches) { [build_match('w1')] }

      before do
        allow(matches).to receive(:has_type?).with(:v) { false }
        allow(matches).to receive(:has_type?).with(:w) { true }
        allow(matches).to receive(:by_type).with(:w) { w_matches }
      end
                        
      it { expect(sentences.reproduction_vw.value).to eq('They are w1s.') }
    end

    context 'when no matches are present' do
      before do
        allow(matches).to receive(:has_type?).with(:v) { false }
        allow(matches).to receive(:has_type?).with(:w) { false }
      end

      it { expect(sentences.reproduction_vw).to_not be_valid }
    end
  end

  describe '#reproduction_y' do
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }
    before { allow(page).to receive(:reproduction_matches) { matches } }

    context 'when there are matches' do

      before do
        allow(page).to receive(:reproduction_matches) { matches }
        allow(matches).to receive(:by_type).with(:y) { y_matches }
        allow(matches).to receive(:has_type?).with(:y) { true }
      end


      def build_match(i) 
        match = instance_double('BriefSummary::ObjUriGroupMatcher::Match')
        predicate = instance_double('TermNode')
        trait = instance_double('Trait')
        predicate_name = "predicate#{i}"
        value = "value#{i}"

        allow(match).to receive(:trait) { trait }
        allow(trait).to receive(:predicate) { predicate }
        allow(predicate).to receive(:name) { predicate_name }
        allow(helper).to receive(:add_trait_val_to_fmt).with("%s #{predicate_name}", trait) { "#{value} #{predicate_name}" }

        match
      end

      let(:y_matches) do 
        [
          build_match(1),
          build_match(2),
          build_match(3)
        ]
      end

      it { expect(sentences.reproduction_y.value).to eq('They have value1 predicate1, value2 predicate2, and value3 predicate3.') }
    end

    context 'when there are no matches' do
      before do
        allow(matches).to receive(:has_type?).with(:y) { false }
      end

      it { expect(sentences.reproduction_y).to_not be_valid }
    end
  end

  def build_x_z_match(i)
    match = instance_double('BriefSummary::ObjUriGroupMatcher::Match')
    trait = instance_double('Trait')

    allow(match).to receive(:trait) { trait }
    allow(helper).to receive(:add_trait_val_to_fmt).with('%s', trait) { "trait#{i}" }

    match
  end

  describe '#reproduction_x' do
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }
    before { allow(page).to receive(:reproduction_matches) { matches } }

    context 'when there are matches' do
      let(:x_matches) { [1, 2, 3].map { |i| build_x_z_match(i) } }

      before do 
        allow(matches).to receive(:has_type?).with(:x) { true }
        allow(matches).to receive(:by_type).with(:x) { x_matches }
      end
        
      context 'when page.extinct?' do
        before { allow(page).to receive(:extinct?) { true } }

        it { expect(sentences.reproduction_x.value).to eq('Reproduction was trait1, trait2, and trait3.') }
      end

      context 'when not page.extinct?' do
        before { allow(page).to receive(:extinct?) { false } }

        it { expect(sentences.reproduction_x.value).to eq('Reproduction is trait1, trait2, and trait3.') }
      end
    end

    context 'when there are no matches' do
      before { allow(matches).to receive(:has_type?).with(:x) { false } }

      it { expect(sentences.reproduction_x).to_not be_valid }
    end
  end

  describe '#reproduction_z' do
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }
    before { allow(page).to receive(:reproduction_matches) { matches } }

    context 'when there are matches' do
      let(:z_matches) { [1, 2, 3].map { |i| build_x_z_match(i) } }

      before do 
        allow(matches).to receive(:has_type?).with(:z) { true }
        allow(matches).to receive(:by_type).with(:z) { z_matches }
      end

      it { expect(sentences.reproduction_z.value).to eq('They have parental care (trait1, trait2, and trait3).') }
    end

    context 'when there are no matches' do
      before { allow(matches).to receive(:has_type?).with(:z) { false } }

      it { expect(sentences.reproduction_z).to_not be_valid }
    end
  end

  describe '#motility' do
    let(:matches) { instance_double('BriefSummary::ObjUriGroupMatcher::Matches') }

    before do 
      allow(page).to receive(:motility_matches) { matches }
      allow(matches).to receive(:has_type?) { false }
    end

    def build_match
      
      match
    end

    context 'when there are c-type matches' do
      let(:match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
      let(:trait) { instance_double('Trait') }
      let(:expected) { 'They rely on <motility> to move around.' }

      before do
        allow(match).to receive(:trait) { trait }
        allow(matches).to receive(:has_type?).with(:c) { true }
        allow(matches).to receive(:first_of_type).with(:c) { match }
        allow(helper).to receive(:add_trait_val_to_fmt).with('They rely on %s to move around.', trait) { expected }
      end

      it { expect(sentences.motility.value).to eq(expected) }
    end

    context 'when there are a and b-type matches' do
      let(:a_match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
      let(:a_trait) { instance_double('Trait') }
      let(:b_match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
      let(:b_trait) { instance_double('Trait') }
      let(:expected) { 'They are <a_trait> <b_trait>s.' }

      before do
        allow(a_match).to receive(:trait) { a_trait }
        allow(b_match).to receive(:trait) { b_trait }
        allow(matches).to receive(:has_type?).with(:a) { true }
        allow(matches).to receive(:has_type?).with(:b) { true }
        allow(matches).to receive(:first_of_type).with(:a) { a_match }
        allow(matches).to receive(:first_of_type).with(:b) { b_match }
        allow(helper).to receive(:add_trait_val_to_fmt).with('They are %s', a_trait) { 'They are <a_trait>' }
        allow(helper).to receive(:add_trait_val_to_fmt).with('They are <a_trait> %s.', b_trait, pluralize: true) { expected }
      end

      it { expect(sentences.motility.value).to eq(expected) }
    end

    context 'when there are a-type matches' do
      let(:match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
      let(:trait) { instance_double('Trait') }

      before do
        allow(matches).to receive(:has_type?).with(:a) { true }
        allow(matches).to receive(:first_of_type).with(:a) { match }
        allow(match).to receive(:trait) { trait }
      end

      context 'when page.animal?' do
        let(:expected) { 'They are <trait> animals.' }

        before do
          allow(page).to receive(:animal?) { true }
          allow(helper).to receive(:add_trait_val_to_fmt).with('They are %s animals.', trait) { expected }
        end

        it { expect(sentences.motility.value).to eq(expected) }
      end

      context 'when not page.animal?' do
        let(:expected) { 'They are <trait> organisms.' }

        before do
          allow(page).to receive(:animal?) { false }
          allow(helper).to receive(:add_trait_val_to_fmt).with('They are %s organisms.', trait) { expected }
        end

        it { expect(sentences.motility.value).to eq(expected) }
      end
    end

    context 'when there are b-type matches' do
      let(:match) { instance_double('BriefSummary::ObjUriGroupMatcher::Match') }
      let(:trait) { instance_double('Trait') }
      let(:expected) { 'They are <trait>s.' }

      before do
        allow(matches).to receive(:has_type?).with(:b) { true }
        allow(matches).to receive(:first_of_type).with(:b) { match }
        allow(match).to receive(:trait) { trait }
        allow(helper).to receive(:add_trait_val_to_fmt).with('They are %s.', trait, pluralize: true) { expected }
      end

      it { expect(sentences.motility.value).to eq(expected) }
    end

    context 'when there are no matches' do
      it { expect(sentences.motility).to_not be_valid }
    end
  end
end

