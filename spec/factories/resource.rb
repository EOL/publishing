FactoryGirl.define do
  factory :resource do
    partner
    sequence(:name) { |n| "Resource #{n}" }
  end
end
