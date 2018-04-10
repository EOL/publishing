FactoryGirl.define do
  factory :vernacular do
    sequence(:string) { |n| "common name #{n}" }
    language { Language.english }
    node
    page { node.page }
  end
end
