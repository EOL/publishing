FactoryGirl.define do
  factory :partner do
    sequence(:name) { |n| "Partner #{n} Full Name" }
    sequence(:short_name) { |n| "Partner #{n}" }
  end
  
  factory :api_partner, class: "Partner" do
    sequence(:full_name) { |n| "Partner #{n} Full Name" }
    sequence(:short_name) { |n| "Partner #{n}" }
  end
end
