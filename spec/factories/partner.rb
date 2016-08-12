FactoryGirl.define do
  factory :partner do
    sequence(:full_name) { |n| "Partner #{n} Full Name" }
    sequence(:short_name) { |n| "Partner #{n}" }
  end
end
