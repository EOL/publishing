FactoryGirl.define do
  factory :scientific_name do
    node
    page { node.page }
    sequence(:canonical_form) { |n| "<i>Scientificus nameri#{(n % 26 + 96).chr}</i>" }
    sequence(:italicized) { |n| "#{canonical_form} Reznor #{1800 + n}" }
    taxonomic_status { TaxonomicStatus.preferred }
    is_preferred false

    factory :preferred_scientific_name do
      is_preferred true
    end
  end
end
