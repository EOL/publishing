FactoryGirl.define do
  factory :resource do
    partner
    sequence(:name) { |n| "Resource #{n}" }
  end
  
  factory :api_resource, class: "Resource" do
    partner { create(:api_partner)}
    sequence(:name) { |n| "Resource #{n}" }
  end
end
