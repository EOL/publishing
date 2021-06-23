require 'rails_helper'

RSpec.describe('BriefSummary::Sentences::Helper') do
  let(:tagger) { instance_double('BriefSummary::TermTagger') }
  let(:view) { double('view_helper') }
  let(:obj_page_fmt) { 'Eaten by %s' }
  let(:obj_page_result) { "Eaten by <a href='/pages/1234'><i>mouse</i></a>" }

  subject(:helper) { BriefSummary::Sentences::Helper.new(tagger, view) }
  subject(:obj_page_helper) { BriefSummary::Sentences::Helper.new(tagger, obj_page_view) }

  describe('#add_term_to_fmt') do
    it 'returns the expected value' do
      label = 'Label'
      predicate = instance_double('TermNode')
      term = instance_double('TermNode')
      source = 'source'

      allow(tagger).to receive(:tag).with(label, predicate, term, source) { '<span>Label</span>' }

      fstr = "Term sentence %s"

      expect(helper.add_term_to_fmt(fstr, label, predicate, term, source)).to(
        eq("Term sentence <span>Label</span>")
      )
    end

    context 'when fstr is blank' do
      it 'raises a TypeError' do
        allow(tagger).to receive(:tag) { 'tag' }

        label = 'label'
        term = instance_double('TermNode')

        expect { helper.add_term_to_fmt('%s', label, nil, term, nil) }.not_to raise_error
        expect { helper.add_term_to_fmt(nil, label, nil, term, nil) }.to raise_error(TypeError)
        expect { helper.add_term_to_fmt('', label, nil, term, nil) }.to raise_error(TypeError)
      end
    end
  end

  let(:obj_page_short_name) { '<i>mouse</i>' }
  let(:obj_page) { instance_double('Page') }
  let(:obj_page_link) { "<a href='/pages/1234'>#{obj_page_short_name}</a>" }
  let(:obj_page_view) { double('view_helper') }

  before do
    allow(obj_page).to receive_message_chain(:short_name, :html_safe) { obj_page_short_name }
    allow(obj_page_view).to receive(:link_to).with(obj_page_short_name, obj_page) { obj_page_link }
  end


  describe('#add_obj_page_to_fmt') do
    context 'with valid arguments' do
      it 'returns the expected value' do
        expect(obj_page_helper.add_obj_page_to_fmt(obj_page_fmt, obj_page)).to eq(obj_page_result)
      end
    end

    context 'when fstr is blank' do
      it 'raises a TypeError' do
        obj_page = instance_double('Page')

        expect { obj_page_helper.add_obj_page_to_fmt(nil, obj_page) }.to raise_error(TypeError)
        expect { obj_page_helper.add_obj_page_to_fmt('', obj_page) }.to raise_error(TypeError)
      end
    end

    context 'when obj_page is nil' do
      it 'substitutes (page not found) for the page link' do
        expect(obj_page_helper.add_obj_page_to_fmt('Eaten by %s', nil)).to eq('Eaten by (page not found)')
      end
    end
  end

  describe '#add_trait_val_to_fmt' do
    let(:trait) { instance_double('Trait') }

    before do
      allow(trait).to receive(:literal) 
      allow(trait).to receive(:predicate)
      allow(trait).to receive(:object_term)
      allow(trait).to receive(:object_page)
      allow(trait).to receive(:id) { 'trait-id' }
    end

    let(:predicate) { instance_double('TermNode') }
    let(:obj_term) { instance_double('TermNode') }

    context 'with valid input' do

      context 'when trait.object_page is present' do
        it 'behaves like #add_obj_page_to_fmt' do
          allow(trait).to receive(:object_page) { obj_page }

          expect(obj_page_helper.add_trait_val_to_fmt(obj_page_fmt, trait)).to eq(obj_page_result)
        end
      end

      context 'when trait.predicate and trait.object_term are present' do
        let(:obj_term_name) { 'carnivore' }

        before do
          allow(obj_term).to receive(:name) { obj_term_name }
          allow(trait).to receive(:predicate) { predicate }
          allow(trait).to receive(:object_term) { obj_term }
        end

        context 'when options[:pluralize] is true' do
          it 'pluralizes object_term.name and returns the expected result' do
            allow(tagger).to receive(:tag).with('carnivores', predicate, obj_term, nil) { '<tag>carnivores</tag>' }

            expect(helper.add_trait_val_to_fmt('They are %s', trait, pluralize: true)).to eq('They are <tag>carnivores</tag>')
          end
        end

        context "wihtout options[:pluralize]" do
          let(:fstr) { 'It is a %s' }
          let(:expected) { 'It is a <tag>carnivore</tag>' }

          before do
            allow(tagger).to receive(:tag).with(obj_term_name, predicate, obj_term, nil) { '<tag>carnivore</tag>' }
          end

          context "when options[:pluralize] is false" do
            it { expect(helper.add_trait_val_to_fmt(fstr, trait, pluralize: false)).to eq(expected) }
          end

          context 'when no options are passed' do
            it { expect(helper.add_trait_val_to_fmt(fstr, trait)).to eq(expected) }
          end
        end
      end

      context 'when trait.literal is present' do
        it 'interpolates the value into fstr' do
          allow(trait).to receive(:literal) { 'awesome' }

          expect(helper.add_trait_val_to_fmt('It is %s', trait)).to eq('It is awesome')
        end
      end
    end

    context 'with invalid trait input' do
      shared_examples 'invalid trait input' do
        it do 
          expect { helper.add_trait_val_to_fmt('%s', trait) }.to raise_error(BriefSummary::BadTraitError)
        end
      end

      context 'when trait.predicate is present but trait.object_term is nil' do
        before { allow(trait).to receive(:predicate) { predicate } }

        it_behaves_like 'invalid trait input'
      end

      context 'when trait.object_term is present but trait.predicate is nil' do
        before { allow(trait).to receive(:object_term) { object_term } }

        it_behaves_like 'invalid trait input'
      end

      context 'when trait only has a literal and it is blank' do
        before { allow(trait).to receive(:literal) { '' } }
        
        it_behaves_like 'invalid trait input'
      end

      context 'when all valid trait attributes are missing' do
        it_behaves_like 'invalid trait input'
      end
    end

    context 'with missing required argument' do
      let(:fstr) { '%s' }

      before do
        allow(trait).to receive(:literal) { 'literal' }
      end

      # ensure that failures aren't due to *bad* input
      context 'with both arguments valid' do
        it { expect { helper.add_trait_val_to_fmt(fstr, trait) }.to_not raise_error }
      end

      context 'with blank fstr' do
        it { expect { helper.add_trait_val_to_fmt('', trait) }.to raise_error(TypeError) }
      end

      context 'with nil fstr' do
        it { expect { helper.add_trait_val_to_fmt(nil, trait) }.to raise_error(TypeError) }
      end

      context 'with nil trait' do
        it { expect { helper.add_trait_val_to_fmt(fstr, nil) }.to raise_error(TypeError) }
      end
    end
  end
end

