FactoryGirl.define do
  factory :rank do
    sequence(:name) { |n| "Rank #{n}" }
  end
end
