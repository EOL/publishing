FactoryGirl.define do
  factory :content_section do
    association :content
    association :section
  end
end