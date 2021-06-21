require 'rails_helper'

RSpec.describe 'BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy' do
  context '#to_s' do 
    def test_locale_and_rank(locale, treat_as)
      full_name = 'Pagename (pagename)'
      a1 = "<a>Ancestor</a>"

      rank = instance_double('Rank')
      allow(rank).to receive(:treat_as) { treat_as }

      page = instance_double('BriefSummary::PageDecorator')
      allow(page).to receive(:full_name_clause) { full_name }
      allow(page).to receive(:a1) { a1 }
      allow(page).to receive(:rank) { rank }

      sentence = BriefSummary::Sentences::I18n::FamilyAndAboveTaxonomy.new(page)
      expected = I18n.t(
        "brief_summary.taxonomy.family_above.#{treat_as}", 
        name1: full_name,
        name2: a1
      )

      expect(sentence.to_s).to eq(expected)
    end

    it "returns the appropriate string for each enabled locale/valid rank" do
      treat_as = %w[ 
        r_superfamily
        r_domain
        r_subdomain
        r_infradomain
        r_superkingdom
        r_kingdom
        r_subkingdom
        r_infrakingdom
        r_superphylum
        r_phylum
        r_subphylum
        r_infraphylum
        r_superclass
        r_class
        r_subclass
        r_infraclass
        r_superorder
        r_order
        r_suborder
        r_infraorder
        r_family
      ]

      I18n.available_locales.each do |l|
        treat_as.each do |t|
          test_locale_and_rank(l, t)
        end
      end
    end
  end
end

